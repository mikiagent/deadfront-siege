class_name TribeDirector
extends Node
## TRIBE M1: the survivor's link between the Tribe roster and the world. Ticks the boat (arrivals,
## departures) and keeps one live TribeMember per record that belongs where she is: at home every
## member and every recruit waiting at the dock; away only the members following her. Bodies live
## under the island runtime, so travelling frees them and the next sync puts them back.

const SYNC_S := 0.5

var player: Player
var live: Dictionary = {}  # uid -> TribeMember
var _sync_left := 0.0
var _version := -1
var _seed_checked := false

func setup(p: Player) -> void:
	player = p

func _physics_process(delta: float) -> void:
	if player == null or World == null or World.creation_pending:
		return
	for text in Tribe.tick(delta):
		player.notice(text)
	_sync_left -= delta
	if _sync_left <= 0.0 or Tribe.version != _version:
		_sync_left = SYNC_S
		sync()

## Home (or a lab with no island loaded): the whole tribe is here.
static func at_home() -> bool:
	return World.runtime == null or World.is_home()

func _host() -> Node:
	return World.runtime if World.runtime and is_instance_valid(World.runtime) else player.get_parent()

func sync() -> void:
	if player == null or not player.is_inside_tree():
		return
	if not _seed_checked and World.runtime and World.is_home() and World.runtime.get("_harbour_pos") != null:
		_seed_checked = true
		if Tribe.seed_starter():
			player.notice("A boat brought %s to the dock" % Tribe.pending[0].name)
	var badge_changed := _version != Tribe.version
	_version = Tribe.version
	var home := at_home()
	var want := {}
	for r in Tribe.members:
		if home or r.is_following():
			want[r.uid] = [r, false]
	if home:
		for r in Tribe.pending:
			want[r.uid] = [r, true]
	for uid in live.keys():
		var m: TribeMember = live[uid]
		if not is_instance_valid(m) or m.is_queued_for_deletion() or not want.has(uid) or m.pending != bool(want[uid][1]) or m.get_parent() != _host():
			if is_instance_valid(m) and not m.is_queued_for_deletion():
				m.queue_free()
			live.erase(uid)
	for uid in want:
		if not live.has(uid):
			live[uid] = _spawn(want[uid][0], want[uid][1])
	if badge_changed:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.get("field") != null:
			hud.field.apply_badge()

func _spawn(r: TribeRecord, pending: bool) -> TribeMember:
	var m := TribeMember.new()
	m.setup(r, pending)
	_host().add_child(m)
	m.global_position = _spawn_point(r, pending)
	return m

## A saved home spot, else the dock (a new arrival steps off the boat), else beside the survivor.
func _spawn_point(r: TribeRecord, pending: bool) -> Vector3:
	var at := player.global_position + Vector3(1.5, 0.0, 1.5)
	if at_home() and not pending and r.pos.size() == 3 and not r.is_following():
		at = Vector3(float(r.pos[0]), float(r.pos[1]), float(r.pos[2]))
	elif at_home() and World.runtime and World.runtime.get("_harbour_pos") != null and not r.is_following():
		var hp: Vector3 = World.runtime.get("_harbour_pos")
		var i := maxi(0, Tribe.pending.find(r))
		at = hp + Vector3(1.2 * float(i) - 1.2, 0.0, 2.5)  # ASSUMPTION: a line on the beach end of the dock
	if World.runtime and World.runtime.has_method("surface_y"):
		at.y = World.runtime.surface_y(at.x, at.z) + TribeMember.HALF_H + 0.05
	elif at.y < TribeMember.HALF_H:
		at.y = TribeMember.HALF_H + 0.05
	return at

func body_of(r: TribeRecord) -> TribeMember:
	if r == null:
		return null
	var m: Variant = live.get(r.uid, null)
	return m if m is TribeMember and is_instance_valid(m) else null
