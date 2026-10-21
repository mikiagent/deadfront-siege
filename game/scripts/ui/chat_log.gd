class_name ChatLog
extends RefCounted
## The chat lines this client keeps (spec 20). Region is the island-room chat over NET
## (contracts.md §7: chat.send {text} -> evt chat {from, id, text, ts} to everyone in the room,
## the sender too); System is the game's own announcements (HUD notices, level-ups, arrivals) and
## works offline. Lines are {from, id, text, ts}, oldest first; ts is server unix time.
## The server is not trusted either: every evt chat field is checked and cleaned again here.

signal changed(channel: StringName)

const REGION := &"region"
const SYSTEM := &"system"
## Per channel; older lines drop. # ASSUMPTION: the server keeps no history, so neither does the client past this.
const MAX_LINES := 100
## A notice repeated within this many seconds refreshes the last System line instead of adding one.
const SYSTEM_REPEAT_S := 5.0

var net: NetClient
var lines := {REGION: [], SYSTEM: []}
## The server's own chat rate (NetServer.RATE_CLASSES "chat"), kept here too: every line the server
## refuses for rate counts toward its flood cut-off, which drops the whole connection, so a held
## Enter or a tapped sticker over the rate is refused here and never sent.
var _rate: TokenBucket

func _init(p_net: NetClient = null) -> void:
	net = p_net
	var r: Array = NetServer.RATE_CLASSES["chat"]
	_rate = TokenBucket.new(r[0], r[1], _clock())
	if net:
		net.event.connect(_on_event)
		net.state_changed.connect(func (_s: int) -> void: changed.emit(REGION))

func online() -> bool:
	return net != null and net.is_online()

## Server time now, so relative times match the server's ts.
func now() -> float:
	return Time.get_unix_time_from_system() + (net.server_time_offset if net else 0.0)

## Sends a region line; await req.done, then req.ok / req.err / req.msg. The line itself comes
## back as evt chat (the server echoes it to the sender), so nothing is added here. Over the
## server's chat rate it ends with err "rate_limited" without reaching the server.
func send(text: String) -> NetRequest:
	if not _rate.take(_clock()):
		var held := NetRequest.new()
		held.op = "chat.send"
		held.finish.call_deferred({"ok": false, "err": "rate_limited", "msg": "slow down"})  # after the caller's await, as NetClient does
		return held
	var req := net.request("chat.send", {"text": text})
	req.done.connect(func (r: NetRequest) -> void:
		if r.err == "rate_limited":
			_rate.tokens = 0.0)  # the server's bucket ran lower than ours: wait a whole token
	return req

static func _clock() -> float:
	return Time.get_ticks_usec() / 1000000.0

func system(text: String) -> void:
	var t := NetChat.clean(text).substr(0, NetChat.MAX_LEN)
	if t == "":
		return
	var sys: Array = lines[SYSTEM]
	if not sys.is_empty() and sys[-1]["text"] == t and now() - float(sys[-1]["ts"]) < SYSTEM_REPEAT_S:
		sys[-1]["ts"] = now()
	else:
		_add(SYSTEM, {"from": "", "id": -1, "text": t, "ts": now()})
	changed.emit(SYSTEM)

func _on_event(ev: String, d: Dictionary) -> void:
	if ev != "chat":
		return
	var id: Variant = NetProtocol.as_int(d.get("id"), 0, NetProtocol.MAX_ID)
	var raw: Variant = d.get("text")
	if id == null or not raw is String or (raw as String).length() > NetChat.MAX_RAW:
		return
	var text := NetChat.clean(raw).substr(0, NetChat.MAX_LEN)
	if text == "":
		return
	var from_raw: Variant = d.get("from")
	var from := NetChat.clean(from_raw).substr(0, 20) if from_raw is String and (from_raw as String).length() <= NetChat.MAX_RAW else ""
	var ts: Variant = d.get("ts")
	var t := minf(float(ts), now()) if NetProtocol.is_num(ts) else now()
	_add(REGION, {"from": from if from != "" else "?", "id": id, "text": text, "ts": t})
	changed.emit(REGION)

func _add(channel: StringName, line: Dictionary) -> void:
	var arr: Array = lines[channel]
	arr.append(line)
	if arr.size() > MAX_LINES:
		arr.pop_front()

## Whether line `l` stacks under `prev`'s name, as the reference stacks one sender's consecutive
## lines: the same sender; System lines (id -1) never stack.
static func stacks(prev: Dictionary, l: Dictionary) -> bool:
	return int(l["id"]) >= 0 and int(prev["id"]) == int(l["id"])

## The reference's grey relative time: "1h 28m ago".
# ASSUMPTION: under a minute reads "just now"; a day or more reads "2d ago".
static func ago(ts: float, now_s: float) -> String:
	var s := maxi(0, int(now_s - ts))
	if s < 60:
		return "just now"
	var m := s / 60
	if m < 60:
		return "%dm ago" % m
	var h := m / 60
	return "%dh %dm ago" % [h, m % 60] if h < 24 else "%dd ago" % (h / 24)
