class_name EatSession
extends Node
## Spec 32 §11 consumption transaction, in order:
##   1. validate   Food.can_eat + the bundle (FoodEffects.evaluate) once, for this exact instance
##   2. timed action (eat_seconds from the bundle, 3 s default) with the keep-still hint
##   3. interrupt on movement: the item is NOT consumed and nothing is granted (energy, buffs,
##      taste and statuses all wait for the commit). Past half a raw meal the raw-food risk still
##      rolls (sec-eat-23) and Full is applied, as before.
##   4. commit: atomically consume *that* instance (the same object, still in that slot), then apply
##      the immediate bundle: instant Energy, Fatigue, Health, Thirst, Fullness, statuses, buffs.
##   5. schedule the delayed Energy with Digestion (persisted remaining, never paid twice).
##   6. buff slots: replace only the eaten buff's own group (BuffSlots).
##   7. taste grade + temperature condition statuses.
##   8. save stays authoritative: EatSession holds no state a reload needs except the in-flight lock,
##      and that lock is only ever set from begin_eat.
##
## Energy used to be dripped in while the eat ran; spec 32 §11.4 gives nothing on a cancel, so the
## instant share is now paid once, at the commit, and the rest over time (Digestion).

const RAW_RISK_CANCEL_AT := 0.5

var player: Player
var progress_ui: EatProgress
var eating: bool = false
var progress: float = 0.0
## Seconds the current eat needs (bundle eat_seconds; 3 s when the item has no bundle).
var eat_seconds: float = Food.EAT_SECONDS
## The evaluated bundle of the instance being eaten (visible to tests/labs).
var bundle: Dictionary = {}
## What the last committed meal actually did, for tests, the lab and the HUD.
var last_paid: Dictionary = {}
## Compatibility snapshot for the established processing lab. FOODFX pays this latent amount as an
## instant/digested split at commit, but callers that inspect an active meal still need its full
## stored Energy value. Do not use this to apply an effect.
var _total_energy: float = 0.0
var _slot_index: int = -1
var _stack_snapshot: ItemStack
## The exact instance in the bag this transaction is about; commit verifies it is still there.
var _instance: ItemStack
## Instance ids already consumed by this session: a second fast intent can never take one twice.
var _consumed: Array[String] = []
## Injectable for reproducible raw-food rolls (tests, server).
var rng: RandomNumberGenerator = null
var risk_rolled: bool = false
var last_risk: StringName = &""

func setup(p: Player, layer: CanvasLayer) -> void:
	player = p
	progress_ui = EatProgress.new()
	progress_ui.name = "EatProgress"
	progress_ui.player = p
	layer.add_child(progress_ui)
	set_process(true)

func reparent_ui(layer: CanvasLayer) -> void:
	if layer and progress_ui and is_instance_valid(progress_ui) and progress_ui.get_parent() != layer:
		progress_ui.reparent(layer)

## The survivor's food clock: buff expiry and delayed digestion advance with the session node, so
## they run in the same place for the game, a test and the lab (Player's own tick is not food's).
func _process(delta: float) -> void:
	if player != null:
		var slots := BuffSlots.of(player)
		if slots != null:
			slots.tick(player, delta)
		var digestion := Digestion.of(player)
		if digestion != null:
			digestion.tick(player, delta)
	advance(delta)

## One step of the timed action. Split from _process so a test can drive fixed deltas.
func advance(delta: float) -> void:
	if not eating or player == null:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length_squared() > 0.04 or player.nav_active:
		_cancel_with_full()
		return
	progress = minf(1.0, progress + delta / maxf(0.1, eat_seconds))
	if progress_ui:
		progress_ui.set_progress(progress)
	if progress >= 1.0:
		_finish()

# ---------------------------------------------------------------- 1. validate

func begin_eat(slot_index: int) -> bool:
	if player == null or eating:
		return false
	if slot_index < 0 or slot_index >= player.inventory.slot_count:
		return false
	var stack := player.inventory.slots[slot_index]
	var why := Food.can_eat(player, stack)
	if why != "":
		print("[food] refuse eat: %s" % why)
		return false
	if instance_key(stack) != "" and instance_key(stack) in _consumed:
		print("[food] refuse eat: that instance was already eaten")
		return false
	# The bundle is evaluated once here for the preview; the commit evaluates it again from the same
	# instance, so the panel and the payment cannot disagree about the instance's state.
	bundle = FoodEffects.preview(stack, player)
	_total_energy = float(bundle.get("latent_energy", Food.energy_restore(stack)))
	_slot_index = slot_index
	_instance = stack
	_stack_snapshot = stack.duplicate_stack()
	_stack_snapshot.count = 1
	eat_seconds = maxf(0.5, float(bundle.get("eat_seconds", Food.EAT_SECONDS)))
	progress = 0.0
	risk_rolled = false
	last_risk = &""
	eating = true
	print("[food] eat start %s energy=%.1f instant=%.1f over %.0fs keep still" % [
		_stack_snapshot.def_id, float(bundle.get("latent_energy", 0.0)),
		float(bundle.get("instant_energy", 0.0)), float(bundle.get("digest_seconds", 0.0))])
	if progress_ui:
		progress_ui.show_eat(_stack_snapshot.def_id, 0.0)
	if player.anim:
		player.anim.on_gather()
	return true

## Identity of one inventory instance: the server's uid when it has one, else its level, level of
## processing and the bag object itself. Never a name or a definition id (spec 32 §10).
func instance_key(stack: ItemStack) -> String:
	if stack == null:
		return ""
	if stack.uid != "":
		return stack.uid
	return "%s|%d|%d|%d" % [str(stack.def_id), stack.level, stack.process_count, stack.get_instance_id()]

# ---------------------------------------------------------------- 4-8. commit

func _finish() -> void:
	if not _commit_consumes():
		_abort("the instance left the bag during the eat")
		return
	var paid := _apply_bundle()
	last_paid = paid
	Tutorial.note("eat")  # TUTORIAL ISLAND: the eat orders count committed meals only
	Tutorial.note("eat:%s" % str(_stack_snapshot.def_id))
	print("[food] eat done %s instant=%.1f digested=%.1f energy=%.1f" % [
		str(_stack_snapshot.def_id), float(paid.get("instant_energy", 0.0)),
		float(paid.get("digested_energy", 0.0)), player.vitals.energy])
	_clear()

## Consume the exact instance the transaction started on. False when the bag changed underneath
## (a market sale, a pet feed): the eat then pays nothing, which is the only safe outcome.
func _commit_consumes() -> bool:
	if player == null or player.inventory == null or _instance == null:
		return false
	if _slot_index < 0 or _slot_index >= player.inventory.slot_count:
		return false
	if player.inventory.slots[_slot_index] != _instance:
		return false
	var key := instance_key(_instance)
	var taken := player.inventory.remove_at(_slot_index, 1)
	if taken == null:
		return false
	if key != "":
		_consumed.append(key)
		while _consumed.size() > 32:
			_consumed.pop_front()
	_stack_snapshot = taken.duplicate_stack()
	_stack_snapshot.count = 1
	bundle = FoodEffects.evaluate(taken, _eval_ctx())
	return true

## The authoritative evaluation: same instance, with the taste memory the survivor carries.
func _eval_ctx() -> Dictionary:
	var ctx := {"taste_memory": {}, "remember_taste": true}
	var slots := BuffSlots.of(player)
	if slots != null:
		ctx["taste_memory"] = slots.taste_memory
	return ctx

func _apply_bundle() -> Dictionary:
	var out := {}
	var v := player.vitals
	var stacks := player.statuses
	var slots := BuffSlots.of(player)
	var digestion := Digestion.of(player)
	# --- Energy: instant share now, the rest scheduled.
	var instant := float(bundle.get("instant_energy", 0.0))
	var digested := float(bundle.get("digested_energy", 0.0))
	if v != null:
		v.energy = clampf(v.energy + instant, 0.0, v.effective_max_energy())
		if digested > 0.0:
			digestion.schedule(_stack_snapshot.def_id, digested, float(bundle.get("digest_seconds", 0.0)))
		# Preserve the established Energy break and process-property relief for foods that have no
		# spec-32 bundle (notably dried/smoked station outputs). Bundled foods own their fatigue
		# effects explicitly in foods.json, so this cannot silently add an old effect to new data.
		if not FoodEffects.has_bundle(_stack_snapshot):
			v.eat(maxf(0.0, instant + digested) * 1.5)
			v.rest(Food.fatigue_relief(_stack_snapshot))
	# --- Fullness, thirst, health, life, fatigue, capacity deltas.
	# A finished meal always applies Full (the rule before spec 32); the bundle may only lengthen it.
	# HUNGER (memo Part 1 s1.4): the food's `fullness` is points added to the stored stomach
	# (Digestion.add_fullness), which then decays on its own. Full stays the status with its own duration.
	var fullness := float(bundle.get("fullness", 0.0))
	if stacks != null:
		_apply_status(stacks, &"full", float(bundle.get("full_seconds", 10.0)))
		if digestion != null:
			digestion.add_fullness(fullness)
		out["fullness"] = fullness
	var thirst := float(bundle.get("thirst", 0.0))
	if stacks != null and thirst > 0.0:
		stacks.clear_id(&"thirsty")
		_apply_status(stacks, &"quenched", float(Data.status(&"quenched").duration) if Data.status(&"quenched") else 360.0)
		out["thirst"] = thirst
	if v != null:
		var hp := float(bundle.get("health", 0.0))
		if hp > 0.0:
			v.heal(hp)
		elif hp < 0.0:
			v.take_damage(-hp)
		out["health"] = hp
		var life := float(bundle.get("life", 0.0))
		if life > 0.0:
			v.heal(life)
		out["life"] = life
		var fatigue := float(bundle.get("fatigue", 0.0))
		if fatigue < 0.0:
			v.rest(-fatigue)  # a drink that lowers *current* fatigue (spec 32 §5), not a cap change
		elif fatigue > 0.0:
			v.add_fatigue(fatigue, &"food")
		out["fatigue"] = fatigue
	# --- Bundle statuses (Caffeinated, a medicine's remedy...).
	if stacks != null:
		for row: Variant in bundle.get("statuses", []):
			if row is Dictionary:
				_apply_status(stacks, StringName(str((row as Dictionary).get("id", ""))), float((row as Dictionary).get("duration", 0.0)), int((row as Dictionary).get("level", 1)))
	# --- Buff slots: replace only the eaten buff's own group.
	if slots != null:
		var replaced := slots.apply(player, bundle.get("buffs", []))
		out["replaced"] = replaced
	# --- Legacy food buffs (food_buffs.json rows from a food's own def and its cooking properties:
	# dried/smoked relief, Warming/Cooling Meal). They stay in the FoodBuffState mirror; the grouped
	# bundle buffs above are the exclusive slots of spec 32 §4.
	Food.apply_buffs(player, _stack_snapshot)
	# --- Taste grade and its status.
	if stacks != null:
		var taste: Dictionary = bundle.get("taste", {})
		var tid := StringName(str(taste.get("status", "")))
		if tid != &"":
			_apply_status(stacks, tid, float(taste.get("duration", 0.0)))
		out["taste"] = taste
	# --- Temperature condition (spec 32 §9): named, no invented resistance numbers.
	if stacks != null:
		var temp := str(bundle.get("temperature", ""))
		var temp_level := int(bundle.get("temperature_level", 1))
		if temp == "hot":
			_apply_status(stacks, &"hot_food", 600.0, temp_level)
		elif temp == "cold":
			_apply_status(stacks, &"cold_food", 600.0, temp_level)
		# --- Raw-food risk (PRD :594): the same roll the old eat ran, on commit only.
		_roll_raw_risk()
	out["instant_energy"] = instant
	out["digested_energy"] = digested
	return out

## `level` is the catalog's "Lv N" (FOODCAT): the status's stacks, never summed across meals (the
## higher level wins), capped by the status's own max_stacks.
func _apply_status(stacks: StatusEffects, id: StringName, seconds: float, level: int = 1) -> void:
	if id == &"" or stacks == null:
		return
	var prior := stacks.get_instance(id)
	var prior_level := prior.stacks if prior != null else 0
	stacks.apply(id, player)
	var inst := stacks.get_instance(id)
	if inst != null and seconds > 0.0:
		inst.time_left = seconds
	var def := Data.status(id)
	if inst != null and def != null:
		inst.stacks = clampi(maxi(prior_level, level), 1, def.max_stacks)

# ---------------------------------------------------------------- 3. interrupt

func _cancel_with_full() -> void:
	print("[food] eat cancelled by move at %d%%; nothing consumed" % int(progress * 100.0))
	if progress >= RAW_RISK_CANCEL_AT:
		_roll_raw_risk()
	_apply_full()
	_clear()

func _abort(why: String) -> void:
	print("[food] eat aborted: %s" % why)
	_clear()

func _roll_raw_risk() -> void:
	risk_rolled = true
	last_risk = Food.apply_raw_risks(player, _stack_snapshot, rng)

func _apply_full() -> void:
	if player and player.statuses:
		_apply_status(player.statuses, &"full", 10.0)

func _clear() -> void:
	eating = false
	progress = 0.0
	_slot_index = -1
	_instance = null
	_stack_snapshot = null
	_total_energy = 0.0
	if progress_ui:
		progress_ui.hide_eat()
