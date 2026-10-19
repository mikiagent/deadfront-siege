class_name PresenceSender
extends Node
## Online mode only: sends the local survivor's position, yaw and clip to its island room at
## 10 Hz (contracts.md §7). Quiet while offline and while the survivor stands still.

const INTERVAL := 0.1
const MOVE_EPS := 0.02
const YAW_EPS := 0.02

var player: Player
var net: NetClient
var rejected := 0  ## updates the server refused (teleport check); probes read it
var _acc := 0.0
var _room := ""
var _last_p := Vector3.INF
var _last_yaw := 0.0
var _last_anim := ""

func _init(p_player: Player, p_net: NetClient = null) -> void:
	name = "PresenceSender"
	player = p_player
	net = p_net

func _ready() -> void:
	if net == null:
		net = Game.net
	net.state_changed.connect(func (_s: int) -> void: _room = "")  # a new socket starts in no room

func _process(delta: float) -> void:
	_acc += delta
	if _acc < INTERVAL:
		return
	_acc = 0.0
	if not net.is_online() or player == null or not is_instance_valid(player):
		return
	var island := room_name()
	if island != _room:
		_room = island
		_last_p = Vector3.INF  # announce ourselves in the new room even if standing still
		net.request("presence.join", {"island": island})
	var p := player.global_position
	var yaw := player.visual.rotation.y if player.visual else 0.0
	var anim := str(player.anim.current_clip) if player.anim else ""
	if anim == "":
		anim = "idle"
	if p.distance_to(_last_p) < MOVE_EPS and absf(angle_difference(yaw, _last_yaw)) < YAW_EPS and anim == _last_anim:
		return
	_last_p = p
	_last_yaw = yaw
	_last_anim = anim
	var req := net.request("presence.update", {"p": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)],
		"yaw": snappedf(yaw, 0.001), "anim": anim, "island": island}, 2.0)
	req.done.connect(_on_update)

## Room id for the current island; the default playfield (no island loaded) is the lobby.
static func room_name() -> String:
	return str(World.island_id) if World.island_id != &"" else PresenceRooms.LOBBY

func _on_update(req: NetRequest) -> void:
	if req.ok or req.err == "offline":
		return
	# Refused (a respawn or recall jumped too far): keep sending until the server's speed window
	# covers the distance, or remote players would see us frozen where we were.
	rejected += 1
	_last_p = Vector3.INF
