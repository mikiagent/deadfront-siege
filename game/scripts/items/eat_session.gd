class_name EatSession
extends Node
## 3 s eat with progress ring + keep-still hint. Move cancels remaining restore; Full still applies.

var player: Player
var progress_ui: EatProgress
var eating: bool = false
var progress: float = 0.0
var _slot_index: int = -1
var _total_energy: float = 0.0
var _applied_energy: float = 0.0
var _stack_snapshot: ItemStack

func setup(p: Player, layer: CanvasLayer) -> void:
	player = p
	progress_ui = EatProgress.new()
	progress_ui.name = "EatProgress"
	layer.add_child(progress_ui)
	set_process(true)

func reparent_ui(layer: CanvasLayer) -> void:
	if layer and progress_ui and is_instance_valid(progress_ui) and progress_ui.get_parent() != layer:
		progress_ui.reparent(layer)

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
	_slot_index = slot_index
	_stack_snapshot = stack.duplicate_stack()
	_stack_snapshot.count = 1
	_total_energy = Food.energy_restore(_stack_snapshot)
	_applied_energy = 0.0
	progress = 0.0
	eating = true
	var taken := player.inventory.remove_at(slot_index, 1)
	if taken == null:
		eating = false
		return false
	print("[food] eat start %s energy=%.1f keep still" % [_stack_snapshot.def_id, _total_energy])
	if progress_ui:
		progress_ui.show_eat(_stack_snapshot.def_id, 0.0)
	if player.anim:
		player.anim.on_gather()
	return true

func _process(delta: float) -> void:
	if not eating or player == null:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length_squared() > 0.04 or player.nav_active:
		_cancel_with_full()
		return
	var before := progress
	progress = minf(1.0, progress + delta / Food.EAT_SECONDS)
	var gained := _total_energy * (progress - before)
	_apply_energy(gained)
	_applied_energy += gained
	if progress_ui:
		progress_ui.set_progress(progress)
	if progress >= 1.0:
		_finish()

func _apply_energy(amount: float) -> void:
	if player == null or player.vitals == null:
		return
	player.vitals.energy = clampf(player.vitals.energy + amount, 0.0, player.vitals.max_energy)

func _finish() -> void:
	Food.apply_raw_risks(player, _stack_snapshot)
	Food.apply_buffs(player, _stack_snapshot)
	_apply_full()
	print("[food] eat done +%.1f energy=%.0f" % [_applied_energy, player.vitals.energy])
	_clear()

func _cancel_with_full() -> void:
	print("[food] eat cancelled by move; Full applied restored=%.1f" % _applied_energy)
	_apply_full()
	_clear()

func _apply_full() -> void:
	if player and player.statuses:
		player.statuses.apply(&"full", player)

func _clear() -> void:
	eating = false
	progress = 0.0
	_slot_index = -1
	_stack_snapshot = null
	_total_energy = 0.0
	_applied_energy = 0.0
	if progress_ui:
		progress_ui.hide_eat()
