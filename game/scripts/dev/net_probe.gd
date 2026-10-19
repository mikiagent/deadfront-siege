extends Node
## --net-probe (tools/net_smoke.sh): a headless client proving two real processes see each other
## online. Circles the survivor slowly, chats once it sees another player, and passes once it
## has a puppet for that player and heard their (server-trimmed) chat.

const TIMEOUT := 45.0
const LINGER := 2.0  # keep sending so the other probe can finish too

var player: Player
var remote: RemotePlayers
var sender: PresenceSender
var _t := 0.0
var _origin := Vector3.ZERO
var _seen: Dictionary = {}  # id -> name
var _heard := ""
var _chat_sent := false
var _passed_at := -1.0
var _passed_puppets := 0  # at the moment PASS was earned; the other probe may have left by the print

func run(p: Player, r: RemotePlayers, s: PresenceSender) -> void:
	player = p
	remote = r
	sender = s
	_origin = p.global_position
	Game.net.state_changed.connect(func (st: int) -> void: print("[netprobe] state %s" % NetClient.State.keys()[st]))
	Game.net.event.connect(_on_event)
	print("[netprobe] start url=%s" % Game.online_url)

func _physics_process(_delta: float) -> void:
	if player and is_instance_valid(player):
		player.global_position = _origin + Vector3(cos(_t * 0.6), 0.0, sin(_t * 0.6)) * 3.0  # ~1.8 m/s

func _process(delta: float) -> void:
	_t += delta
	if not _seen.is_empty() and not _chat_sent and Game.net.is_online():
		_chat_sent = true
		Game.net.request("chat.send", {"text": "  hello from %s\u0007  " % Game.net.account_name})
		print("[netprobe] chat sent as %s" % Game.net.account_name)
	var clean := _heard != "" and _heard == _heard.strip_edges() and not "\u0007" in _heard
	if _passed_at < 0.0 and clean and remote.puppet_count() > 0:
		_passed_at = _t
		_passed_puppets = remote.puppet_count()
	if _passed_at >= 0.0 and _t - _passed_at > LINGER:
		print("[netprobe] PASS me=%s saw=%s heard=\"%s\" puppets=%d rejected=%d" % [Game.net.account_name,
			_seen.values(), _heard, _passed_puppets, sender.rejected])
		set_process(false)
		get_tree().quit(0)
	elif _t > TIMEOUT:
		print("[netprobe] FAIL state=%s me=%s saw=%s heard=\"%s\" puppets=%d error=%s" % [NetClient.State.keys()[Game.net.state],
			Game.net.account_name, _seen.values(), _heard, remote.puppet_count(), Game.net.last_error])
		set_process(false)
		get_tree().quit(1)

func _on_event(ev: String, d: Dictionary) -> void:
	if ev == "presence" and d.get("players") is Array:
		for row in d["players"]:
			if row is Dictionary and int(row.get("id", -1)) != Game.net.account_id and not _seen.has(int(row.get("id", -1))):
				_seen[int(row["id"])] = str(row.get("name", "?"))
				print("[netprobe] saw id=%d name=%s p=%s" % [int(row["id"]), _seen[int(row["id"])], row.get("p")])
	elif ev == "chat" and int(d.get("id", -1)) != Game.net.account_id:
		_heard = str(d.get("text", ""))
		print("[netprobe] chat from=%s text=\"%s\"" % [d.get("from"), _heard])
