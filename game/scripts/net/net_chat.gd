class_name NetChat
extends RefCounted
## Island-room chat (contracts.md §7): chat.send {text} → evt chat {from, id, text, ts} to the
## sender's room, after invisible and control characters are stripped, odd spaces normalised,
## stacked combining marks capped and edges trimmed. A line with nothing visible is refused.

const MAX_LEN := 200
const MAX_RAW := 2000  # refuse absurd input before scanning it
const MAX_MARKS := 3  # ASSUMPTION: combining marks per base; enough for real text (Vietnamese stacks 2), zalgo stacks hundreds

## Every control (Cc), format (Cf: soft hyphen, zero-width, joiners, bidi, tags, U+061C...),
## private-use (Co: a different glyph per font) and line or paragraph separator: they break lines,
## hide characters or spoof other text. This also splits emoji ZWJ sequences and drops Persian
## ZWNJ; readable beats faithful here. Unassigned code points (Cn) stay: they draw a box, and
## this engine's tables would class emoji newer than them as unassigned.
static var _strip_re := RegEx.create_from_string("[\\p{Cc}\\p{Cf}\\p{Co}\\p{Zl}\\p{Zp}]")
## Read as a plain space: every other space (NBSP, U+3000...) and the blank "letters" used as
## invisible text (Hangul fillers U+115F, U+1160, U+3164, U+FFA0; braille blank U+2800).
static var _space_re := RegEx.create_from_string("[\\p{Zs}\\x{115F}\\x{1160}\\x{3164}\\x{FFA0}\\x{2800}]")
static var _marks_re := RegEx.create_from_string("(\\p{M}{%d})\\p{M}+" % MAX_MARKS)
## A line must draw something: one character that is not a space, mark or control.
static var _ink_re := RegEx.create_from_string("[^\\s\\p{Z}\\p{M}\\p{Cc}\\p{Cf}]")

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

## The text to relay, or "" when nothing visible is left.
static func clean(s: String) -> String:
	var t := _space_re.sub(_strip_re.sub(s, "", true), " ", true)
	t = _marks_re.sub(t, "$1", true).strip_edges()
	return t if _ink_re.search(t) != null else ""
