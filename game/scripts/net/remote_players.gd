class_name RemotePlayers
extends Node3D
## Online mode only: one RemotePuppet per other player in my island room (contracts.md §7),
## driven by evt presence / presence_leave / chat. Everything from the server is validated
## again here; a bad row is skipped, never trusted.

const MAX_PUPPETS := 128

var net: NetClient
var _puppets: Dictionary = {}  # account id -> RemotePuppet

func _init(p_net: NetClient = null) -> void:
	name = "RemotePlayers"
	net = p_net

func _ready() -> void:
	if net == null:
		net = Game.net
	net.event.connect(_on_event)
	net.state_changed.connect(func (s: int) -> void:
		if s != NetClient.State.ONLINE:
			clear()
	)
	World.island_changed.connect(func (_id: StringName) -> void: clear())  # the server sends the new room

func puppet(id: int) -> RemotePuppet:
	return _puppets.get(id)

func puppet_count() -> int:
	return _puppets.size()

func clear() -> void:
	for p: RemotePuppet in _puppets.values():
		p.queue_free()
	_puppets.clear()

func _on_event(ev: String, d: Dictionary) -> void:
	match ev:
		"presence":
			var rows: Variant = d.get("players")
			if rows is Array:
				for row in rows:
					_apply(row)
		"presence_leave":
			var id: Variant = NetProtocol.as_int(d.get("id"), 0, NetProtocol.MAX_ID)
			if id != null and _puppets.has(id):
				(_puppets[id] as RemotePuppet).queue_free()
				_puppets.erase(id)
		"chat":
			var id: Variant = NetProtocol.as_int(d.get("id"), 0, NetProtocol.MAX_ID)
			var text: Variant = d.get("text")
			if id != null and text is String and _puppets.has(id):
				(_puppets[id] as RemotePuppet).say((text as String).substr(0, NetChat.MAX_LEN))

func _apply(row: Variant) -> void:
	if not row is Dictionary:
		return
	var id: Variant = NetProtocol.as_int(row.get("id"), 0, NetProtocol.MAX_ID)
	var p: Variant = row.get("p")
	var yaw: Variant = row.get("yaw")
	if id == null or id == net.account_id or not NetProtocol.is_vec3(p) or not NetProtocol.is_num(yaw):
		return
	var pos := Vector3(float(p[0]), float(p[1]), float(p[2]))
	var pup: RemotePuppet = _puppets.get(id)
	if pup == null:
		if _puppets.size() >= MAX_PUPPETS:
			return
		pup = RemotePuppet.new()
		add_child(pup)
		pup.setup(id, str(row.get("name", "?")).substr(0, 20), pos, float(yaw))
		_puppets[id] = pup
	pup.set_target(pos, float(yaw), str(row.get("anim", "idle")).substr(0, 32))
