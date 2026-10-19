class_name NetChat
extends RefCounted
## Island-room chat (contracts.md §7): chat.send {text} → evt chat {from, id, text, ts} to the
## sender's room, after invisible and control characters are stripped, stacked combining marks
## are capped and edges are trimmed.

const MAX_LEN := 200
const MAX_RAW := 2000  # refuse absurd input before scanning it
const MAX_MARKS := 3  # ASSUMPTION: combining marks per base; enough for real text (Vietnamese stacks 2), zalgo stacks hundreds

## Every control (Cc), format (Cf: soft hyphen, zero-width, joiners, bidi, tags, U+061C...) and
## line or paragraph separator: they break lines, hide characters or spoof other text. This also
## splits emoji ZWJ sequences and drops Persian ZWNJ; readable beats faithful here.
static var _strip_re := RegEx.create_from_string("[\\p{Cc}\\p{Cf}\\p{Zl}\\p{Zp}]")
static var _marks_re := RegEx.create_from_string("(\\p{M}{%d})\\p{M}+" % MAX_MARKS)

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
	return _marks_re.sub(_strip_re.sub(s, "", true), "$1", true).strip_edges()
