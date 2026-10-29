class_name ZoneSpawner
extends Node3D
## TUTORIAL ISLAND wild lands: a creature group that exists only while the survivor is near.
## On a 4-5x island the ring spawns would put every animal on the map at build time; a zone instead
## spawns its group when the survivor comes within `wake_m` and removes the living ones once she is
## farther than `sleep_m` (never mid-hunt), so only the zones around her cost anything. Checked at
## 2 Hz. Respects Game.max_creatures_per_island. A killed animal stays dead for `respawn_s`.
## shortcut: one zone = one Spawner row, no persistence; a save reload starts every zone fresh.

var species: StringName = &"compsognathus"
var count: int = 1
var as_pack: bool = false
var wake_m: float = 110.0
var sleep_m: float = 170.0
var respawn_s: float = 240.0
var _live: Array[Creature] = []
var _acc := 0.0
var _down_until := 0.0

func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.5:
		return
	_acc = 0.0
	var p := PlayerRegistry.local()
	if p == null:
		return
	_live = _live.filter(func (c: Creature) -> bool: return is_instance_valid(c) and not c.is_queued_for_deletion() and c.health != null and not c.health.dead)
	var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
	var now := float(Time.get_ticks_msec()) / 1000.0
	if _live.is_empty() and d <= wake_m and now >= _down_until:
		_wake()
	elif not _live.is_empty() and d > sleep_m:
		_sleep(p)

func _wake() -> void:
	var rt := get_parent()
	var live_total := get_tree().get_nodes_in_group("creatures").size()
	var room := Game.max_creatures_per_island - live_total
	if room <= 0:
		return
	var sp := Spawner.new()
	sp.species = species
	sp.count = mini(count, room)
	sp.as_pack = as_pack
	sp.position = position
	rt.add_child(sp)
	for c in sp.spawn_now():
		_live.append(c)
		c.tree_exiting.connect(_on_gone.bind(c))
	sp.queue_free()

func _on_gone(c: Creature) -> void:
	if c.health != null and c.health.dead:
		_down_until = float(Time.get_ticks_msec()) / 1000.0 + respawn_s

func _sleep(p: Player) -> void:
	for c in _live:
		if p.hunt and p.hunt.target == c:
			return  # never pull an animal out of a fight
	for c in _live:
		if is_instance_valid(c):
			c.queue_free()
	_live.clear()

func awake_count() -> int:
	return _live.size()
