class_name NetProtocol
extends RefCounted
## Wire format shared by NetServer and NetClient (contracts.md §2, §3): frames, error codes and
## the small validators every trust boundary uses. JSON numbers always arrive as floats.

const MAX_FRAME := 65536
const MAX_ID := 2147483647
## Contract §2's codes, then the five W1-SRVDOM's intents return (its report asks the orchestrator to
## add them to §2). # ASSUMPTION: they go on the wire as they are.
const ERR_CODES: Array[String] = ["bad_request", "unauthorized", "rate_limited", "not_found",
	"insufficient_funds", "insufficient_items", "not_owner", "self_trade", "expired", "closed",
	"bid_too_low", "limit_reached", "invalid_asset", "conflict", "server_error",
	"out_of_range", "depleted", "missing_tool", "bag_full", "not_ready"]

## Validators anchor with \z: PCRE's $ also matches before a trailing newline, so "x\n" would pass.
static var _name_re := RegEx.create_from_string("^[A-Za-z0-9 _-]{3,20}\\z")
static var _token_re := RegEx.create_from_string("^[0-9a-f]{64}\\z")
static var _name_char_re := RegEx.create_from_string("[^A-Za-z0-9 _-]")

static func ok(r: Dictionary = {}) -> Dictionary:
	return {"ok": true, "r": r}

## r on a failure carries what the client needs to act on it (limit_reached: next_instance).
# ASSUMPTION: §2's error envelope may carry r; contract §7 needs it to name the next instance.
static func fail(code: String, msg: String, r: Dictionary = {}) -> Dictionary:
	var res := {"ok": false, "err": code if code in ERR_CODES else "server_error", "msg": msg}
	if not r.is_empty():
		res["r"] = r
	return res

## A handler result is {ok:true, r:{}} or {ok:false, err:<stable code>, msg, r?}; anything else is a bug.
static func is_result(res: Variant) -> bool:
	if not res is Dictionary or not res.get("ok") is bool or not res.get("r", {}) is Dictionary:
		return false
	return res["ok"] or (str(res.get("err", "")) in ERR_CODES and res.get("msg", "") is String)

static func res_frame(id: int, res: Dictionary) -> String:
	var out := {"t": "res", "id": id, "ok": res.get("ok") == true}
	if out["ok"]:
		out["r"] = res.get("r", {})
	else:
		out["err"] = res.get("err", "server_error")
		out["msg"] = res.get("msg", "")
		if not (res.get("r", {}) as Dictionary).is_empty():
			out["r"] = res["r"]
	return JSON.stringify(out)

static func evt_frame(ev: String, d: Dictionary) -> String:
	return JSON.stringify({"t": "evt", "ev": ev, "d": d})

## Whole number in [lo, hi], or null. Rejects 1.5, NaN, inf and strings.
static func as_int(v: Variant, lo: int, hi: int) -> Variant:
	if typeof(v) == TYPE_INT:
		return v if v >= lo and v <= hi else null
	if typeof(v) != TYPE_FLOAT or not is_finite(v) or v != floorf(v) or v < lo or v > hi:
		return null
	return int(v)

static func is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and is_finite(v))

static func is_vec3(v: Variant, limit: float = 100000.0) -> bool:
	if not v is Array or (v as Array).size() != 3:
		return false
	for x in v:
		if not is_num(x) or absf(float(x)) > limit:
			return false
	return true

static func valid_name(n: String) -> bool:
	return _name_re.search(n) != null and n == n.strip_edges()

static func is_token(t: String) -> bool:
	return _token_re.search(t) != null

## Client side: turn a character name into something auth.hello accepts.
static func sanitize_name(raw: String) -> String:
	var n := _name_char_re.sub(raw, "", true).strip_edges().substr(0, 20).strip_edges()
	return n if n.length() >= 3 else "Survivor%04d" % randi_range(0, 9999)

## Client side: a name was taken, try "<name>-123" (still ≤ 20 chars).
static func suffix_name(n: String) -> String:
	return "%s-%03d" % [n.substr(0, 16).strip_edges(), randi_range(0, 999)]

## True once every byte written to f is on disk. On a full disk store_*() and flush() still report
## success (seen with Godot 4.7.1 on macOS); only the length shows the bytes never landed.
static func flushed(f: FileAccess) -> bool:
	f.flush()
	return f.get_error() == OK and f.get_length() == f.get_position()

static func uuid4(crypto: Crypto) -> String:
	var b := crypto.generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
