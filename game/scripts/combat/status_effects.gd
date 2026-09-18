class_name StatusEffects
extends Node
## Three-debuff cap. Fourth replaces the lowest weakness_rank.

signal applied(id: StringName, stacks: int)
signal removed(id: StringName)

var _active: Array[StatusInstance] = []
var _tick_acc: float = 0.0

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

func apply(id: StringName, source: Node = null, extra_stacks: int = 1) -> void:
	var parsed := parse_token(id)
	var real_id: StringName = parsed["id"]
	var add_stacks: int = int(parsed["stacks"]) * extra_stacks
	var def := Data.status(real_id)
	if def == null:
		push_warning("[status] unknown %s" % real_id)
		return
	var existing: StatusInstance = get_instance(real_id)
	if existing:
		existing.stacks = mini(def.max_stacks, existing.stacks + add_stacks)
		existing.time_left = def.duration
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
	inst.stacks = mini(def.max_stacks, add_stacks)
	inst.time_left = def.duration
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
		if def.dps_max_hp_frac > 0.0:
			dps += def.dps_max_hp_frac * cr.health.max_hp
		if dps > 0.0:
			cr.health.take_damage(dps * 0.5, inst.source)
	elif host is Player:
		var pl := host as Player
		if def.dps_max_hp_frac > 0.0:
			dps += def.dps_max_hp_frac * pl.vitals.max_health
		if dps > 0.0:
			pl.vitals.take_damage(dps * 0.5)
		if def.fatigue_per_min > 0.0:
			pl.vitals.add_fatigue(def.fatigue_per_min * (0.5 / 60.0) * 100.0 * float(inst.stacks), inst.id)

func _expire(inst: StatusInstance) -> void:
	var def := Data.status(inst.id)
	if def and def.on_untreated_expire != &"" and not inst.treated:
		if randf() < def.on_untreated_chance:
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

func _sync_vitals() -> void:
	var p := get_parent()
	if p is Player:
		(p as Player).vitals.blocks_regen = blocks_regen()
		var mh := 1.0
		for inst in _active:
			var def := Data.status(inst.id)
			if def:
				mh *= def.max_health_mult
		(p as Player).vitals.max_health = 100.0 * mh
		(p as Player).vitals.health = minf((p as Player).vitals.health, (p as Player).vitals.effective_max_health())
