class_name NetChat
extends RefCounted
## Island-room chat (contracts.md §7): chat.send {text} → evt chat {from, id, text, ts} to the
## sender's room, after control and bidi-override characters are stripped and edges trimmed.

const MAX_LEN := 200
const MAX_RAW := 2000  # refuse absurd input before scanning it

## C0, DEL, C1, zero-width and direction-override characters: they break lines or spoof names.
static var _strip_re := RegEx.create_from_string(
	"[\\x{0}-\\x{1F}\\x{7F}-\\x{9F}\\x{200B}-\\x{200F}\\x{2028}-\\x{202E}\\x{2060}-\\x{206F}\\x{FEFF}]")

var _server: NetServer
var _presence: PresenceRooms

func _init(server: NetServer, presence: PresenceRooms) -> void:
	_server = server
	_presence = presence

func op_send(aid: int, a: Dictionary) -> Dictionary:
	var raw: Variant = a.get("text")
	if not raw is String or (raw as String).length() > MAX_RAW:
		return NetProtocol.fail("bad_request", "text must be a string of at most %d characters" % MAX_LEN)
	var text := clean(raw)
	if text.is_empty() or text.length() > MAX_LEN:
		return NetProtocol.fail("bad_request", "chat text must be 1-%d characters" % MAX_LEN)
	var members := _presence.room_members(aid)
	if members.is_empty():
		return NetProtocol.fail("bad_request", "join an island before chatting")
	var ts := _server.wall_time()
	_server.broadcast_event(members, "chat", {"from": _server.account_name(aid), "id": aid, "text": text, "ts": ts})
	return NetProtocol.ok({"ts": ts})

static func clean(s: String) -> String:
	return _strip_re.sub(s, "", true).strip_edges()
