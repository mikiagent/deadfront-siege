class_name StatusEffects
extends Node
## Three-debuff cap. Fourth replaces the lowest weakness_rank.

signal applied(id: StringName, stacks: int)
signal removed(id: StringName)

var _active: Array[StatusInstance] = []
var _tick_acc: float = 0.0
## True while a damage-over-time tick lands on a Player (Player._on_vitals_damaged tells it from a hit).
var ticking: bool = false

func _process(delta: float) -> void:
	_tick_acc += delta
	var tick := false
	if _tick_acc >= 0.5:
		_tick_acc -= 0.5
		tick = true
	var dying: Array[StatusInstance] = []
	for inst: StatusInstance in _active:
		inst.time_left -= delta
		if inst.time_left <= 0.0:
			dying.append(inst)
		elif tick:
			_dot(inst)
	for inst: StatusInstance in dying:
		_expire(inst)

## The old status set is gone (a load or a respawn): max HP goes back to the survivor's own maximum.
## apply() syncs on a real add, but an empty set has nothing to sync.
func clear_all() -> void:
	if _active.is_empty():
		return
	_active.clear()
	_sync_vitals()

func apply(id: StringName, source: Node = null, extra_stacks: int = 1) -> void:
	var parsed := parse_token(id)
	var real_id: StringName = parsed["id"]
	# Creature counter statuses must never become percent-health player injuries.
	if get_parent() is Player and real_id in [&"bleeding_target", &"poisoned_target"]:
		return
	# Raid control is earned through timed blunt counters, not random groggy/stun chains.
	if get_parent() is Creature:
		var host := get_parent() as Creature
		if host.def and host.def.id == &"tyrannosaurus" and real_id in [&"groggy",&"knockdown",&"snared",&"pinned"]: return
	var add_stacks: int = int(parsed["stacks"]) * extra_stacks
	var def := Data.status(real_id)
	if def == null:
		push_warning("[status] unknown %s" % real_id)
		return
	var existing: StatusInstance = get_instance(real_id)
	if existing:
		existing.stacks = mini(_max_stacks(real_id, def.max_stacks), existing.stacks + add_stacks)
		existing.time_left = _duration(real_id, def.duration)
		existing.source = source
		print("[status] %s +%s x%d" % [_who(), real_id, existing.stacks])
		applied.emit(real_id, existing.stacks)
		return
	if _active.size() >= 3:
		var weakest: StatusInstance = _weakest()
		if weakest and Data.status(weakest.id).weakness_rank <= def.weakness_rank:
			_drop(weakest, false)
		else:
			return
	var inst: StatusInstance = StatusInstance.new()
	inst.id = real_id
	inst.stacks = mini(_max_stacks(real_id, def.max_stacks), add_stacks)
	inst.time_left = _duration(real_id, def.duration)
	inst.source = source
	_active.append(inst)
	print("[status] %s +%s x%d" % [_who(), real_id, inst.stacks])
	applied.emit(real_id, inst.stacks)
	_sync_vitals()

func clear_id(id: StringName) -> void:
	var inst: StatusInstance = get_instance(id)
	if inst:
		inst.treated = true
		_drop(inst, false)

func extend(id: StringName, extra_seconds: float) -> void:
	var inst := get_instance(id)
	if inst == null:
		return
	inst.time_left += maxf(0.0, extra_seconds)

func clear_by_item(item_id: StringName) -> bool:
	var cleared := false
	for inst in _active.duplicate():
		var def := Data.status(inst.id)
		if def and item_id in def.cleared_by:
			inst.treated = true
			_drop(inst, false)
			cleared = true
	return cleared

func has(id: StringName) -> bool:
	return get_instance(id) != null

func get_instance(id: StringName) -> StatusInstance:
	for inst: StatusInstance in _active:
		if inst.id == id:
			return inst
	return null

func instances() -> Array[StatusInstance]:
	return _active

func to_array() -> Array:
	var out: Array = []
	for inst in _active:
		out.append({"id": str(inst.id), "stacks": inst.stacks, "time_left": inst.time_left})
	return out

func from_array(raw: Array) -> void:
	_active.clear()
	for row in raw:
		if not row is Dictionary:
			continue
		apply(StringName(str(row.get("id", ""))), null, int(row.get("stacks", 1)))
		var inst := get_instance(StringName(str(row.get("id", ""))))
		if inst:
			inst.time_left = float(row.get("time_left", inst.time_left))
	_sync_vitals()  # the status part of max HP follows the loaded set (SAVEFIX)

func has_flag(flag: StringName) -> bool:
	for inst in _active:
		var def := Data.status(inst.id)
		if def and def.has_flag(flag):
			return true
	return false

func move_mult() -> float:
	var m := 1.0
	for inst in _active:
		var def := Data.status(inst.id)
		if def:
			m *= def.move_mult
	return m

func defense_mult() -> float:
	var m := 1.0
	for inst in _active:
		var def := Data.status(inst.id)
		if def:
			m *= def.defense_mult
	return m

func attack_mult() -> float:
	var m := 1.0
	for inst in _active:
		var def := Data.status(inst.id)
		if def:
			m *= def.attack_mult
	return m

func accuracy_mult() -> float:
	var m := 1.0
	for inst in _active:
		var def := Data.status(inst.id)
		if def:
			m *= def.accuracy_mult
	return m

## Dodge percentage points from statuses (dizziness -40); callers scale by evasion_add_scale.
func evasion_add() -> float:
	var e := 0.0
	for inst in _active:
		var def := Data.status(inst.id)
		if def:
			e += def.evasion_add
	return e

## Fatigue gain multipliers of the active statuses (Dirty, Clean, Thirsty; Quenched for heat).
func fatigue_mult() -> float:
	return _product(&"fatigue_mult")

func heat_fatigue_mult() -> float:
	return _product(&"heat_fatigue_mult")

func _product(field: StringName) -> float:
	var m := 1.0
	for inst in _active:
		var def := Data.status(inst.id)
		if def:
			m *= float(def.get(field))
	return m

func blocks_regen() -> bool:
	return has_flag(&"blocks_regen")

func can_act() -> bool:
	return not has_flag(&"cannot_act")

static func parse_token(token: StringName) -> Dictionary:
	var s := str(token)
	if s.begins_with("bleed_") and s != "bleeding_target":
		var n := int(s.get_slice("_", 1))
		return {"id": &"bleed", "stacks": maxi(1, n)}
	return {"id": token, "stacks": 1}

func _dot(inst: StatusInstance) -> void:
	var def := Data.status(inst.id)
	if def == null:
		return
	var dps := def.dps * float(inst.stacks)
	var host := get_parent()
	if host is Creature:
		var cr := host as Creature
		if inst.id in [&"bleeding_target", &"poisoned_target"]:
			# Never force damage onto a capturable animal: the same window as the net (spec 09,
			# stunned at any HP or <= 30 %) decides. The bot's first tame kept dying to bleed
			# between "weak enough" and the tackle. Direct hits still kill.
			if FieldTame.capture_window(cr):
				return
			dps = CombatCounters.dot_dps(cr.def.archetype, inst.id, cr.health.max_hp, inst.stacks)
		elif def.dps_max_hp_frac > 0.0:
			dps += def.dps_max_hp_frac * cr.health.max_hp
		if dps > 0.0:
			var dealt := dps * 0.5
			var origin: Node = inst.source if is_instance_valid(inst.source) else null
			if inst.siege_origin and is_instance_valid(inst.siege_origin.get_ref()):
				origin = inst.siege_origin.get_ref()
			cr.health.take_damage(dealt, origin)
			if cr.has_method("on_status_tick_damage"):
				cr.on_status_tick_damage(inst.id, dealt)
	elif host is Player:
		var pl := host as Player
		if def.dps_max_hp_frac > 0.0:
			dps += def.dps_max_hp_frac * pl.vitals.max_health
		if dps > 0.0:
			ticking = true
			pl.vitals.take_damage(dps * 0.5)
			ticking = false
		if def.fatigue_per_min > 0.0:
			# fatigue_per_min is a rate on the 0-100 fatigue scale (PRD's +5.4/min, +18/min), per
			# tick of 0.5 s. It used to be multiplied by 100 as well: Wet charged 30/min.
			pl.vitals.add_fatigue(def.fatigue_per_min * (0.5 / 60.0) * float(inst.stacks), inst.id)

func _expire(inst: StatusInstance) -> void:
	var def := Data.status(inst.id)
	if def and def.on_untreated_expire != &"" and not inst.treated:
		if CombatTuning.roll(def.on_untreated_chance):
			_drop(inst, false)
			apply(def.on_untreated_expire)
			return
	_drop(inst, false)

func _drop(inst: StatusInstance, silent: bool) -> void:
	_active.erase(inst)
	if not silent:
		print("[status] %s -%s" % [_who(), inst.id])
		removed.emit(inst.id)
	_sync_vitals()

func _weakest() -> StatusInstance:
	var best: StatusInstance = null
	var rank := 999
	for inst in _active:
		var def := Data.status(inst.id)
		if def and def.weakness_rank < rank:
			rank = def.weakness_rank
			best = inst
	return best

func _who() -> String:
	var p := get_parent()
	if p is Creature:
		return str((p as Creature).def.id) if (p as Creature).def else p.name
	return p.name if p else "?"

## Max HP an active status takes away (Infected Wound x0.8), as a multiplier on the survivor's own
## maximum (100 + pioneer levels). 1.0 when no status changes it.
func max_health_status_mult() -> float:
	return _product(&"max_health_mult")

## The line the HUD shows under the status chips when a status changes max HP, else "". SAVEFIX: a
## max HP that moves must say why (playtest: 102/105 -> 100/100 with no visible cause).
func max_health_note() -> String:
	for inst in _active:
		var def := Data.status(inst.id)
		if def == null or is_equal_approx(def.max_health_mult, 1.0):
			continue
		var pct := int(round((def.max_health_mult - 1.0) * 100.0))
		return "%s: max HP %+d%%" % [def.display_name, pct]
	return ""

func _sync_vitals() -> void:
	var p := get_parent()
	if p is Player:
		var pl := p as Player
		pl.vitals.blocks_regen = blocks_regen()
		# Only the status part is this node's to set: the pioneer-level bonus (vitals.level_health)
		# stayed lost because every status change rewrote max_health to a flat 100 x product.
		pl.vitals.max_health = (100.0 + pl.vitals.level_health) * max_health_status_mult()
		pl.vitals.health = minf(pl.vitals.health, pl.vitals.effective_max_health())

## Only creature counter statuses use the counter clock; player injuries are unchanged.
func _duration(id: StringName, fallback: float) -> float:
	return CombatCounters.dot_duration(id, fallback) if get_parent() is Creature else fallback

func _max_stacks(id: StringName, fallback: int) -> int:
	return CombatCounters.max_stacks(id, fallback) if get_parent() is Creature else fallback
