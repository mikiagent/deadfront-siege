class_name Provenance
extends RefCounted
## Contract v2 §0.5: every stack and pet the server mints carries uid + origin + the journal
## seq of the op that minted it. Only assets with this stamp may leave a character for the vault.

const ORIGINS: Array[String] = ["gather", "loot", "craft", "tame", "breed", "settlers", "objective", "market"]
const KEYS: Array[String] = ["uid", "origin", "seq"]

## "i<seq>.<k>": the k-th stack op <seq> minted. The dot keeps character uids apart from the
## economy ledger's "i<n>" ids, which come from a different counter.
static func item_uid(seq: int, k: int) -> String:
	return "i%d.%d" % [seq, k]

static func pet_uid(seq: int, k: int) -> String:
	return "p%d.%d" % [seq, k]

static func stamp(d: Dictionary, uid: String, origin: String, seq: int) -> Dictionary:
	d["uid"] = uid
	d["origin"] = origin
	d["seq"] = seq
	return d

## A copy without the stamp, for domain classes that should see only the gameplay fields.
static func strip(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	for k in KEYS:
		out.erase(k)
	return out

static func is_server(d: Variant) -> bool:
	if not d is Dictionary:
		return false
	var uid: Variant = d.get("uid")
	return uid is String and (uid as String).length() >= 4 and str(d.get("origin", "")) in ORIGINS and d.get("seq") is int and int(d.seq) > 0
