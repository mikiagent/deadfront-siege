class_name PlayerActions
extends RefCounted
## The survivor's command layer: every verb that changes the bag, gear, the world or a creature
## (gather, loot, craft, place, equip, eat, tame, attack, drink, wash, rest) goes through here. Offline each verb
## applies locally exactly as before. Online (W3-SRVACT) the same call becomes an `act.<verb>`
## intent for the server (contracts.md section 0.3) and nothing changes locally until the
## server's delta arrives. To add a verb (W2-ACTION: swing, dodge, block, aim): add one method
## that returns `_send(verb, args)` when online and applies locally otherwise, then call it
## from PlayerInput.

const GATHER_FATIGUE_PER_UNIT := 1.5 / 4.0 # ASSUMPTION: per-unit fatigue is one quarter of legacy per-gather cost.
const CORPSE_TAKE_SECONDS := 1.6
## F with no target: hunt the nearest wild animal within this range.
# ASSUMPTION: Hunt's own 28 m leash (F used to pick the nearest creature at any range, pets included).
const ATTACK_SEEK_RANGE := 28.0

var p: Player
## Online mode routes verbs to the server; offline (default) applies them here.
var online: bool = false
## Intents built while online. shortcut: queued, not sent; W3-SRVACT swaps _send for the socket.
var sent: Array[Dictionary] = []
var _corpse_slot: int = -1
var _gather_unit_time: float = 1.0
## XPECON: the seconds the last gather pass really took (tools and Gathering shorten it). The pass
## pays rules.json xp.gather_base + round(this), so faster work pays less XP and slow work pays more.
var _gather_pass_seconds: float = 1.0

func _init(player: Player) -> void:
	p = player

## The online path: record the intent the server will run. Returns false: nothing applied locally.
# ASSUMPTION: ids are local instance ids until W3 gives replicated nodes net ids.
func _send(verb: StringName, args: Dictionary) -> bool:
	sent.append({"op": "act.%s" % verb, "a": args})
	return false

static func net_id(n: Object) -> int:
	return n.get_instance_id() if n else 0

## Work in progress (gather, butcher, tame feed): the route ends within reach of it.
func has_target() -> bool:
	return (p.gather_target and is_instance_valid(p.gather_target)) \
		or (p.butcher_target and is_instance_valid(p.butcher_target)) \
		or (p.tame_target and is_instance_valid(p.tame_target))

func cancel_work() -> void:
	p.gather_target = null
	p.butcher_target = null
	p.tame_target = null
	p.tame_food_id = &""
	stop_gather_cycle()
	if p.station_craft and p.station_craft.crafting:
		p.station_craft.cancel_and_refund()

# ---------------------------------------------------------------- gather

## Pick `option` on a node and gather it (walk there, then one unit per cycle).
func gather(node: HarvestNode, option: int) -> bool:
	if online:
		return _send(&"gather", {"node_id": net_id(node), "option": option})
	node.select_option(option)
	print("[item] option %s x%d-%d %.1fs" % [node.yield_def_id, node.yield_min, node.yield_max, node.gather_seconds])
	return begin_gather(node)

func begin_gather(node: HarvestNode) -> bool:
	# Ask the node first: the tier gate lives in can_gather, and auto-equip used to answer a bare
	# "need tool pick" before it. Refusals reach the HUD, not only the log.
	var why := node.can_gather(p.inventory)
	if why != "":
		print("[item] refused %s: %s" % [node.node_id, why])
		# Upper-case the first letter only: capitalize() Title-Cased "Need Tool Axe".
		p.notice("Picked clean" if why == "depleted" else why.left(1).to_upper() + why.substr(1))
		return false
	auto_equip_tool(node.required_tool_class)  # can_gather found it with the same lookup
	stop_gather_cycle(false)
	p.butcher_target = null
	p.gather_target = node
	p.nav_to(p.sim.closest_nav_point(node.global_position))
	return true

## Put the right tool in hand for a job (axe for trees, pick for rocks, knife for corpses).
## Returns false when the bag has none. The held-tool hex and the hand model follow.
func auto_equip_tool(tool_class: StringName) -> bool:
	if tool_class == &"" or tool_class == &"none":
		return true
	var tool := p.inventory.find_gather_tool(tool_class)
	if tool == null:
		return false
	var idx := p.inventory.slots.find(tool)
	if idx >= 0 and idx != p.inventory.equipped_tool_index:
		p.inventory.set_equipped_tool_index(idx)
		print("[item] auto-equip %s %s" % [tool.def_id, tool_class])
	return true

## The route ended: start whatever the survivor walked over to do.
func on_arrived() -> void:
	var gt := p.gather_target
	if gt and is_instance_valid(gt) and p.global_position.distance_to(gt.global_position) > 3.2:
		print("[path] could not reach %s" % gt.node_id)
		p.gather_target = null
		p.view.clear_ground_marker()
		return
	p.view.clear_ground_marker()
	if gt and is_instance_valid(gt):
		p.face_world(gt.global_position)
		var why := gt.can_gather(p.inventory)
		if why != "":
			print("[item] refused %s: %s" % [gt.node_id, why])
			p.notice("Can't gather: %s" % why.replace("_", " "))
			stop_gather_cycle()
			p.gather_target = null
			return
		_start_gather_cycle(_scaled_gather_seconds(gt))
	elif p.tame_target and is_instance_valid(p.tame_target):
		p.face_world(p.tame_target.global_position)
		_start_tame_feed()
	elif p.butcher_target and is_instance_valid(p.butcher_target):
		p.face_world(p.butcher_target.global_position)
		if _corpse_slot >= 0:
			_corpse_take_timer(p.butcher_target, _corpse_slot)
		else:
			p.butcher_target.open_loot(p)
		p.butcher_target = null

## Per frame while walking/standing: advance the gather or tame-feed cycle.
func tick_work(delta: float) -> void:
	if not p._gathering:
		return
	p._gather_left -= delta
	var progress := 1.0 - (p._gather_left / maxf(0.001, _gather_unit_time))
	var taming := p.tame_target and is_instance_valid(p.tame_target)
	if taming:
		_update_tame_ring(progress)
	else:
		_update_gather_ring(progress)
	if p._gather_left <= 0.0:
		if taming:
			_finish_tame_feed()
		else:
			finish_gather()

func finish_gather() -> void:
	p._gathering = false
	var gt := p.gather_target
	if gt == null or not is_instance_valid(gt):
		stop_gather_cycle()
		return
	var why := gt.can_gather(p.inventory)
	if why != "":
		print("[item] refused %s: %s" % [gt.node_id, why])
		stop_gather_cycle()
		p.gather_target = null
		return
	if gt.required_tool_class != &"" and gt.required_tool_class != &"none":
		if not p.inventory.wear_gather_tool(gt.required_tool_class):
			stop_gather_cycle()
			p.gather_target = null
			return
	var stack := gt.roll_yield()
	var yield_mult := _gather_yield_multiplier(gt)
	stack.count = maxi(1, int(floor(float(stack.count) * yield_mult)))
	if randf() < fmod(yield_mult, 1.0):
		stack.count += 1
	if p.skills:
		# rules.json gathering_downrank: a node above your Gathering level yields at your level.
		# ASSUMPTION: floor of 5 so a fresh survivor still gets usable materials.
		var cap := maxi(p.skills.level_of("gathering"), 5)
		if stack.level > cap:
			stack.level = cap
			stack.attributes["level"] = cap
		# XPECON (islands-and-loop 3.3/3.4): the pass pays 1 + round(its own seconds), so bare hands
		# and a slow node pay more, a better tool or a higher Gathering level pay less. SkillState
		# mirrors every grant into World.add_xp, so the character bar follows.
		p.skills.add_xp("gathering", gather_pass_xp(_gather_unit_time))
		if gt.family.begins_with("Rock") or gt.family == "clay":
			p.skills.add_xp("processing", 1)
	var attrs := stack.attributes.duplicate(true)
	var before := stack.count
	var had := p.inventory.uids()  # W2-GATHER: the units this pass lands are the instances not in it
	var left := p.inventory.add(stack)
	var gained := before - left
	if gained <= 0:
		print("[item] refused %s: inventory_full" % gt.node_id)
		p.notice("Bag is full.")
		stop_gather_cycle()
		p.gather_target = null
		return
	gt.consume_unit()
	GatherService.after_unit(p, gt, stack, gained, had)  # W2-GATHER: helper-tool wear, rare traits and finds, yield popup
	if p._gather_radial and p._gather_radial.is_open():
		p._gather_radial.refresh()
	print("[item] +%d %s %s (pool %d/%d)" % [gained, stack.def_id, attrs, gt.pool_units_left(), gt.pool_max])
	if p.skills == null:
		World.add_xp(gather_pass_xp(_gather_unit_time))
	p.toast(stack.def_id, gained)
	p.vitals.add_fatigue(GATHER_FATIGUE_PER_UNIT, &"gather")
	WaterAccess.soil(p, &"gather")
	if gt.pool_units_left() <= 0:
		stop_gather_cycle()
		p.gather_target = null
		return
	_start_gather_cycle(_scaled_gather_seconds(gt))

## XPECON (islands-and-loop 3.3/3.4): one gather pass pays rules.json xp.gather_base plus the pass's
## own whole seconds, so the stone (4 s) and log (4 s) passes pay 5 and a berry pass (2 s) pays 3,
## and a tool or a Gathering level that shortens the work shortens the award with it.
static func gather_pass_xp(seconds: float) -> int:
	var cfg: Dictionary = Data.world_rules.get("xp", {})
	return int(cfg.get("gather_base", 1)) + int(roundf(maxf(0.0, seconds)))

func _scaled_gather_seconds(node: HarvestNode) -> float:
	return GatherService.unit_seconds(p, node)  # W2-GATHER: role tool helps, bare hands slower

func _gather_yield_multiplier(node: HarvestNode) -> float:
	return GatherService.yield_multiplier(p, node)

func _start_gather_cycle(seconds: float) -> void:
	p._gathering = true
	_gather_unit_time = maxf(0.1, seconds)
	p._gather_left = _gather_unit_time
	if p.anim:
		p.anim.on_gather(p.gather_target.gather_kind() if p.gather_target and is_instance_valid(p.gather_target) else &"")
	_update_gather_ring(0.0)

func stop_gather_cycle(fade_ring: bool = true) -> void:
	p._gathering = false
	p._gather_left = 0.0
	if p._gather_ring:
		if fade_ring:
			p._gather_ring.fade_out()
		else:
			p._gather_ring.clear_now()
	var radial := p._gather_radial
	if fade_ring and radial and radial.is_open() and radial.active_index >= 0:
		radial.close()  # the gather ended (cancelled, pool empty, bag full): drop the menu

## While the radial is open on this node the picked hex shows the unit progress; otherwise
## the floating hex over the node does.
func _update_gather_ring(progress: float) -> void:
	var radial := p._gather_radial
	if radial and radial.is_open() and p.gather_target and radial.active_node() == p.gather_target:
		radial.set_progress(progress)
		if p._gather_ring:
			p._gather_ring.clear_now()
		return
	if p._gather_ring == null:
		return
	if p.gather_target and is_instance_valid(p.gather_target):
		p._gather_ring.show_for(p.gather_target, progress)
	else:
		p._gather_ring.fade_out()

## A hex picked on the shared radial: a field action, a corpse stack or a gather option.
func on_option_picked(anchor: Node3D, index: int) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	if anchor is FieldPlot:
		var field := anchor as FieldPlot
		var opts := p._field_radial_opts if p._field_radial_target == field else field.radial_options(p)
		if index >= 0 and index < opts.size():
			field.apply_action(p, opts[index] as Dictionary)
		p._field_radial_target = null
		p._field_radial_opts.clear()
		return
	if anchor is Corpse:
		var opts := (anchor as Corpse).loot_options(p.inventory)
		if index < opts.size():
			begin_corpse_take(anchor as Corpse, int(opts[index]["slot"]))
		return
	if anchor is HarvestNode:
		gather(anchor as HarvestNode, index)

# ---------------------------------------------------------------- tame

func begin_field_tame(creature: Creature) -> bool:
	if not FieldTame.can_attempt(creature):
		return false
	var food := FieldTame.food_in_bag(p.inventory, creature)
	if food == &"":
		print("[tame] refused: %s" % FieldTame.refuse_message(creature))
		return false
	if online:
		return _send(&"tame", {"net_id": net_id(creature), "food": str(food)})
	if p.hunt:
		p.hunt.stop()
	stop_gather_cycle(false)
	p.gather_target = null
	p.butcher_target = null
	p.tame_target = creature
	p.tame_food_id = food
	p.nav_to(p.sim.closest_nav_point(creature.global_position))
	return true

func _start_tame_feed() -> void:
	var t := p.tame_target
	if t == null or not is_instance_valid(t) or not FieldTame.can_attempt(t):
		_clear_tame_target()
		return
	if p.tame_food_id == &"" or p.inventory.find_first(p.tame_food_id) < 0:
		print("[tame] refused: %s" % FieldTame.refuse_message(t))
		_clear_tame_target()
		return
	p._gathering = true
	_gather_unit_time = FieldTame.FEED_SECONDS
	p._gather_left = _gather_unit_time
	if p.anim:
		p.anim.on_gather()
	_update_tame_ring(0.0)

func _finish_tame_feed() -> void:
	p._gathering = false
	var t := p.tame_target
	if t == null or not is_instance_valid(t):
		_clear_tame_target()
		return
	var food := p.tame_food_id if p.tame_food_id != &"" else FieldTame.food_in_bag(p.inventory, t)
	FieldTame.apply_feed(p, t, food)
	_clear_tame_target()

func _clear_tame_target() -> void:
	p.tame_target = null
	p.tame_food_id = &""
	stop_gather_cycle()

func _update_tame_ring(progress: float) -> void:
	var ring = p._gather_ring
	if ring == null:
		return
	if p.tame_target and is_instance_valid(p.tame_target) and ring.has_method("show_for_tame"):
		ring.show_for_tame(p.tame_target, progress, p.tame_food_id)
	else:
		ring.fade_out()

func pen_interact(pen: TamingPen) -> void:
	# E2: with the HUD up, the pen opens the Taming Pen screen (tame-or-store, timer, feed); a lab
	# or test without a HUD keeps the direct insert / feed path below.
	var hud := p.get_tree().get_first_node_in_group("hud") if p.is_inside_tree() else null
	if hud != null and hud.has_method("open_taming_pen"):
		hud.call("open_taming_pen", pen)
		return
	if pen.running:
		pen.feed(p)
	else:
		pen.try_insert(p)

# ---------------------------------------------------------------- loot

## Tap the loot box on the floor: walk over and open it as a chest screen (bag on the left,
## loot on the right, Take all). The knife rule shows in the screen as a read-only note.
func open_corpse_loot(corpse: Corpse) -> void:
	if corpse == null:
		return
	stop_gather_cycle(false)
	p.gather_target = null
	p.tame_target = null
	p.tame_food_id = &""
	_corpse_slot = -1
	auto_equip_tool(&"knife")
	if p.global_position.distance_to(corpse.global_position) <= 2.6:
		p.clear_nav()
		p.face_world(corpse.global_position)
		p.butcher_target = null
		corpse.open_loot(p)
		return
	p.butcher_target = corpse
	p.nav_to(p.sim.closest_nav_point(corpse.global_position))

func begin_butcher(corpse: Corpse) -> void:
	var why := corpse.can_butcher(p.inventory)
	if why == "empty":
		print("[item] refused butcher %s: %s" % [corpse.species, why])
		return
	var tool := p.inventory.find_gather_tool(&"knife")
	if tool and why == "":
		print("[item] auto-equip %s knife" % tool.def_id)
	stop_gather_cycle(false)
	p.gather_target = null
	p.tame_target = null
	p.tame_food_id = &""
	_corpse_slot = -1
	p.butcher_target = corpse
	p.nav_to(p.sim.closest_nav_point(corpse.global_position))

## Radial take of one loot stack: walk over, butcher for CORPSE_TAKE_SECONDS, then loot(...).
func begin_corpse_take(corpse: Corpse, slot: int) -> void:
	stop_gather_cycle(false)
	p.gather_target = null
	p.tame_target = null
	p.tame_food_id = &""
	p.butcher_target = corpse
	_corpse_slot = slot
	p.nav_to(p.sim.closest_nav_point(corpse.global_position))

func _corpse_take_timer(corpse: Corpse, slot: int) -> void:
	_corpse_slot = -1
	if p.anim:
		p.anim.on_gather()
	p.vitals.add_fatigue(1.0, &"gather")
	p.get_tree().create_timer(CORPSE_TAKE_SECONDS).timeout.connect(func () -> void: loot(corpse, slot))

## Move one corpse loot stack into the bag. Only what fits moves; the rest stays in the corpse
## (sec-loss-08), and Butchering XP is paid only when units moved (sec-xpfarm-07), once per drop kind.
func loot(corpse: Corpse, slot: int) -> int:
	if corpse == null or not is_instance_valid(corpse) or slot < 0 or slot >= corpse.loot.slot_count:
		return 0
	var st := corpse.loot.slots[slot]
	if st == null:
		return 0
	if online:
		_send(&"loot", {"corpse_id": net_id(corpse), "slot": slot})
		return 0
	var def_id := st.def_id
	var moved := corpse.loot.transfer_to(p.inventory, slot)
	if moved <= 0:
		p.notice("Bag is full.")
		return 0
	p.inventory.wear_gather_tool(&"knife")
	print("[item] +%d %s (loot %s)" % [moved, def_id, corpse.species])
	if corpse.first_take_of(def_id): # W2-INV: once per drop kind, not per instance taken
		if p.skills:
			p.skills.add_xp("butchering", 3)
		else:
			World.add_xp(3)
		WaterAccess.soil(p, &"butcher") # one loot stack's grime (water.json), per kind as XP is
	p.toast(def_id, moved)
	return moved

# ---------------------------------------------------------------- water (spec 17)

## Drink, wash, or fill an empty bucket at fresh water (PRD :105, :314). The rules are WaterAccess's.
func drink() -> bool:
	if online:
		return _send(&"drink", {})
	return WaterAccess.drink(p)

func wash() -> bool:
	if online:
		return _send(&"wash", {})
	return WaterAccess.wash(p)

func fill_water() -> bool:
	if online:
		return _send(&"fill", {})
	return WaterAccess.fill(p)

# ---------------------------------------------------------------- rest

## Sit down to rest, or get up when already resting (the Rest hex, the X key). Online the intent
## carries the wanted state, so a retried send does not flip it back. The rules are RestState's.
func rest() -> bool:
	var on := not p.sim.rest.resting
	if online:
		return _send(&"rest", {"on": on})
	if on:
		return p.sim.rest.start()
	p.sim.rest.stop()
	return true

# ---------------------------------------------------------------- craft, eat, equip, place

func craft(rid: StringName, count: int = 1) -> bool:
	if p.station_craft == null:
		return false
	if online:
		return _send(&"craft", {"recipe_id": str(rid), "count": count})
	cancel_work()
	if p.hunt:
		p.hunt.stop()
	p.station_craft.begin(rid, count)
	return true

## COLLECT on a process station (drying rack, smoker, crock pot, steamer): its finished outputs into
## the bag, one toast per item id (a rack can hold dried meat and dried hide at once).
func collect(st: Node3D) -> bool:
	if online:
		return _send(&"collect", {"station": net_id(st)})
	var ps := ProcessStation.of(st)
	if ps == null or ps.collect_into(p.inventory, p) <= 0:
		return false
	for id in ps.last_collected:
		p.toast(id, int(ps.last_collected[id]))
	return true

## TAKE BACK on a process station: jobs still waiting for a slot return their own inputs to the bag.
func take_back(st: Node3D) -> bool:
	if online:
		return _send(&"take_back", {"station": net_id(st)})
	var ps := ProcessStation.of(st)
	return ps != null and ps.take_back_into(p.inventory, p) > 0

func eat(index: int) -> bool:
	if online:
		return _send(&"eat", {"slot": index})
	return p.eat_session != null and p.eat_session.begin_eat(index)

func equip(slot: StringName, def_id: StringName) -> bool:
	if online:
		return _send(&"equip", {"slot": str(slot), "def_id": str(def_id)})
	p.inventory.equip(slot, def_id)
	return true

## Confirm the building ghost (place_confirm key or tap on the ghost).
func place_confirm() -> bool:
	if online:
		return _send(&"place", {"kind": str(p.placer.placing)})
	p.placer.confirm(p)
	return true

# ---------------------------------------------------------------- attack

## F / pad X, or a tap on a wild animal: swing now when it is in reach (HOLD and Auto-off still
## swing), otherwise start the hunt that walks over. Pets are never targets (pc-bug-01).
func attack(target: Creature = null) -> bool:
	if Game.lab_flat_attack:
		var c := nearest_creature(9999.0, false)
		if c:
			p.play_attack()
			c.health.take_damage(100.0, p)
			print("[combat] lab F 100 → %s hp=%.0f" % [c.def.id, c.health.hp])
		return c != null
	var hunt := p.hunt
	if target == null:
		target = hunt.target if hunt.target and is_instance_valid(hunt.target) and not hunt.target.health.dead else nearest_creature(ATTACK_SEEK_RANGE, false)
	if target == null or target.is_pet:
		# Nothing alive to hit: a swing clears the scenery in front (owner: most props can be
		# destroyed; a cliff refuses and stays). ASSUMPTION: clearing gives no loot.
		return clear_prop_in_front()
	if target.is_pet:
		return false
	if online:
		return _send(&"attack", {"net_id": net_id(target)})
	if hunt.target != target:
		hunt.start(target)
	return hunt.swing_now()

## The pet radial's Rename: the character-name rule (CharacterStore.name_problem). Returns "" or why not.
func rename_pet(rec: PetRecord, new_name: String) -> String:
	var nm := new_name.strip_edges()
	var why := CharacterStore.name_problem(nm)
	if rec == null or why != "":
		return why if why != "" else "no pet"
	if online:
		_send(&"pet_rename", {"pet_uid": rec.uid, "name": nm})
		return ""
	rec.name = nm
	print("[pets] renamed %s to %s" % [rec.species, nm])
	return ""

## One swing at the scenery: the nearest destroyable prop in front of the survivor goes.
func clear_prop_in_front() -> bool:
	if World == null or World.runtime == null:
		return false
	var props: Variant = World.runtime.get("props")
	if props == null or not is_instance_valid(props) or not props.has_method("clear_in_front"):
		return false
	if not bool(props.call("clear_in_front", p, 2.6)):
		return false
	p.play_attack()
	return true

func nearest_creature(max_d: float, include_pets: bool) -> Creature:
	var best: Creature = null
	var best_d := max_d
	for n in p.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.health.dead or (c.is_pet and not include_pets):
			continue
		var d := p.global_position.distance_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best

func use_medicine() -> void:
	if p.inventory.consume(&"bandage", 1):
		p.statuses.clear_id(&"bleed")
		print("[item] used bandage")
		return
	if p.inventory.consume(&"pressure_dressing", 1):
		p.statuses.clear_id(&"deep_bleed")
		print("[item] used pressure_dressing")

## Normal context action. One dose gives three landed hits; never overwrites live charges.
func coat_weapon() -> bool:
	var weapon := p.inventory.equipped_weapon()
	if p.dead or p.rolling or p.anim._busy or p.vitals.in_combat or (p.hunt and p.hunt.target != null):
		p.notice("Coat your weapon outside combat")
		return false
	if weapon == null or int(weapon.attributes.get("toxin_hits", 0)) > 0:
		p.notice("Equip an uncoated weapon")
		return false
	if not p.inventory.consume(&"toxin_coating", 1): return false
	weapon.attributes["toxin_hits"] = 3
	p.inventory.changed.emit()
	p.notice("Toxin ready:3 landed hits")
	return true

## Place one snare 2 m ahead using normal HUD action, valid dry terrain and real inventory.
func place_snare(id: StringName) -> bool:
	if id not in [&"rope_snare", &"heavy_snare"] or p.dead or p.rolling or p.anim._busy: return false
	var rt := World.runtime
	if rt == null: return false
	var forward := -p.visual.global_basis.z
	forward.y = 0
	var at := p.global_position + forward.normalized() * 2.0
	at.y = rt.surface_y(at.x, at.z) + 0.08
	if not rt.spawn_ok(at, false):
		p.notice("Snare needs dry ground")
		return false
	var grid: BuildGrid = rt.get("build_grid") as BuildGrid
	var cell := BuildGrid.tile_of(at)
	if grid and (cell in grid.occupied_cells() or cell in grid.reserved_cells()):
		p.notice("Snare needs clear ground")
		return false
	for node in p.get_tree().get_nodes_in_group("harvest"):
		if node is Node3D and (node as Node3D).global_position.distance_to(at) < 1.0:
			p.notice("Snare needs clear ground")
			return false
	for node in p.get_tree().get_nodes_in_group("ground_snare"):
		if (node as Node3D).global_position.distance_to(at) < 2.5:
			p.notice("Snares need space")
			return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.35
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3(0,0.5,0))
	query.exclude = [p.get_rid()]
	for contact in p.get_world_3d().direct_space_state.intersect_shape(query, 8):
		var collider: Object = contact.get("collider")
		if collider is StaticBody3D and (collider as Node).name != "Floor":
			p.notice("Snare needs clear ground")
			return false
	if online:
		return _send(&"place", {"kind": str(id), "cell": [cell.x, cell.y], "rot": 0})
	if not p.inventory.consume(id, 1): return false
	var snare := GroundSnare.new()
	snare.heavy = id == &"heavy_snare"
	rt.add_child(snare)
	snare.global_position = at
	p.notice("Snare armed in1s, lasts2min")
	return true

## Claim a 14x14 plot here. Home: free (expansion by Pioneer level is M10's problem).
## Unstable: the first plot is free, later ones consume a claim_stake. ASSUMPTION.
## A survivor who holds no plot on this island stakes one straight away (first claim, the tutorial
## flow). Holding any plot, the same press only asks: the HUD opens its CLAIM confirm and only that
## panel's confirm calls claim_confirmed(). A press never moves or drops land already held; the
## plots only ever add, so nothing can be orphaned by a press. ASSUMPTION: the PRD (13.1) and spec
## 18 are silent on a second claim; they describe expansions, one free then paid, which this is.
func claim() -> void:
	var rt := World.runtime
	if rt == null or not rt.has_method("claim_at"):
		return
	# CLAIMS2 / spec 29: at the cap the press says so before it asks, naming the numbers.
	var capped: String = str(rt.call("claim_limit_reason")) if rt.has_method("claim_limit_reason") else ""
	if capped != "":
		print("[world] claim refused: %s" % capped)
		p.notice("%s. Raise your Pioneer rank (or the Communications Center) to claim more." % capped)
		return
	if not (rt.get("claims") as Array).is_empty():
		if online:
			p.notice("Expanding a claim online is not wired yet.")
			return
		var hud := p.get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_claim_confirm"):
			hud.call("open_claim_confirm")
			return
		print("[world] claim refused: you already hold land here; nothing moved")
		p.notice("You already hold land here. Nothing moved.")
		return
	claim_confirmed()

## Stake the plot under the survivor. The CLAIM confirm calls this; a first claim calls it directly.
## True when the plot is yours now (a refused plot keeps the stake and the free first plot).
func claim_confirmed() -> bool:
	var rt := World.runtime
	if rt == null or not rt.has_method("claim_at"):
		return false
	# PRD 13.1: with land already held a claim is one orthogonal expansion of it, never a plot out on
	# its own (the confirm path runs this too, so a stale panel cannot stake a hop).
	if not (rt.get("claims") as Array).is_empty() and rt.has_method("claim_expand_reason"):
		var why := str(rt.call("claim_expand_reason", BuildGrid.tile_of(p.global_position)))
		if why != "":
			print("[world] claim refused: %s" % why)
			p.notice("Can't claim here: %s" % why)
			return false
	var stake := not World.is_home() and World.free_claim_used
	if stake and p.inventory.count_of(&"claim_stake") < 1:
		print("[world] claim refused: needs claim_stake")
		p.notice("Needs a claim stake.")
		return false
	var why_now := str(rt.call("claim_expand_reason", BuildGrid.tile_of(p.global_position)))
	if not rt.claim_at(BuildGrid.tile_of(p.global_position)):
		print("[world] claim refused: %s" % why_now)
		p.notice("Can't claim here: %s." % (why_now if why_now != "" else "not dry land, or another survivor's"))
		return false
	# Paid only once the plot is yours: a refused claim keeps the stake (and the free first plot).
	if stake:
		p.inventory.consume(&"claim_stake", 1)
	if not World.is_home():
		World.free_claim_used = true
	return true

# ---------------------------------------------------------------- structures

## Tap on a placed structure. Gates open and close (structure.interact), shift-tap at home packs
## any kind up (one shared pack-up, all-or-nothing on the bag), baskets open their storage.
func building_interact(b: Node) -> void:
	if World.is_home() and Input.is_action_pressed("sprint"):
		BuildPlacer.pack_up_node(b, p)
		return
	if b.has_method("interact") and b.interact(p):
		return
	if b is FieldPlot:
		p.open_field(b as FieldPlot)
		return
	if b.is_in_group("construction_site"):
		b.call("interact", p)
		return
	if StationCraft.is_craft_station(b) or b.is_in_group("sleep_spot"):
		p.open_station_craft(b as Node3D)
		return
	if str(b.get("kind")) == "basket" and b.get("storage") and p.ui:
		var pet := p.pets.nearest(9999.0)
		if pet and pet.pet_record and pet.pet_record.bag:
			p.pets.dump_bag_into(pet, b.storage)
		p.ui.show_storage(b.storage, p, {"title":"Basket","allow_deposit":true})
		return
	if str(b.get("kind")) == "sign":
		print("[world] sign: %s" % (str(b.get("sign_text")) if str(b.get("sign_text")) != "" else "(blank)"))
		return
	if str(b.get("kind")) == "well" or str(b.get("station_id")) == "well":
		p.open_station_craft(b as Node3D)
