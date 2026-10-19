class_name Ledger
extends RefCounted
## The economy's books: wallets, vaults keyed by uid, fee sink, faucet, id issue, inboxes.
## State is plain JSON-shaped data (string keys, ints where integral, no shared references),
## so the snapshot is the state and a replay can rebuild it byte for byte.
## Escrow lives on the records that own it: an auction's `bid`, a buy order's `escrow`.

const SETTLERS := 0

var s: Dictionary
var rules: EconRules
var now: int = 0
var events: Array = [] ## [account_id, event] created by the current op, for the transport to push

func _init(p_rules: EconRules, state: Dictionary = {}) -> void:
	rules = p_rules
	s = state if not state.is_empty() else genesis()

static func genesis() -> Dictionary:
	return {
		"v": 1, "seq": 0, "last_ts": 0, "next_id": 1,
		"accounts": {}, "listings": {}, "closed_listings": {}, "orders": {}, "closed_orders": {},
		"fee_sink": 0, "initial_grants": 0, "faucet": {"objectives": 0, "settlers": 0},
		"items_in": {}, "items_out": {}, "items_consumed": {}, "pets_in": 0, "pets_out": 0,
		"trades": [], "history": {}, "ref": {}, "ref_trades": {}, "pairs": {},
		"settlers": {"day": -1, "hour": -1},
	}

func acct(id: int) -> Dictionary:
	return s.accounts.get(str(id), {})

func new_account(id: int, name: String) -> Dictionary:
	var a := {
		"id": id, "name": name, "created": now, "wallet": 0, "vault_items": {}, "vault_pets": {},
		"claimed": [], "inbox": [], "rid_cache": {}, "rid_order": [], "deposits": {}, "trades": [],
		"open_listings": 0, "open_orders": 0,
	}
	s.accounts[str(id)] = a
	return a

## Ids come from one counter that only moves inside ops, so replay issues the same ids.
func new_id(prefix: String) -> String:
	var n: int = s.next_id
	s.next_id = n + 1
	return "%s%d" % [prefix, n]

static func id_num(id: String) -> int:
	return int(id.substr(1))

func grant_start(id: int, amount: int) -> void:
	acct(id).wallet += amount
	s.initial_grants += amount

func mint(id: int, amount: int, source: String) -> void:
	acct(id).wallet += amount
	s.faucet[source] = int(s.faucet.get(source, 0)) + amount

func debit(id: int, amount: int) -> void:
	var a := acct(id)
	assert(amount >= 0 and int(a.wallet) >= amount, "econ: debit past zero")
	a.wallet = int(a.wallet) - amount

func credit(id: int, amount: int) -> void:
	assert(amount >= 0, "econ: negative credit")
	acct(id).wallet += amount

func to_sink(amount: int) -> void:
	s.fee_sink += amount

## Removes `count` units of a vault stack. The whole stack keeps its uid; a part gets a new one.
func take_item(id: int, uid: String, count: int) -> Dictionary:
	var vault: Dictionary = acct(id).vault_items
	var stack: Dictionary = vault[uid]
	if count >= int(stack.count):
		vault.erase(uid)
		return stack
	stack.count = int(stack.count) - count
	var part := stack.duplicate(true)
	part.count = count
	part.uid = new_id("i")
	return part

func put_item(id: int, stack: Dictionary) -> void:
	acct(id).vault_items[stack.uid] = stack

func take_pet(id: int, uid: String) -> Dictionary:
	var vault: Dictionary = acct(id).vault_pets
	var pet: Dictionary = vault[uid]
	vault.erase(uid)
	return pet

func put_pet(id: int, pet: Dictionary) -> void:
	acct(id).vault_pets[pet.uid] = pet

func put_asset(id: int, kind: String, asset: Dictionary) -> void:
	if kind == "pet":
		put_pet(id, asset)
	else:
		put_item(id, asset)

func bump(counter: String, key: String, n: int) -> void:
	var d: Dictionary = s[counter]
	d[key] = int(d.get(key, 0)) + n

func inbox(id: int, ev: String, d: Dictionary) -> void:
	if id == SETTLERS:
		return
	var e := {"id": new_id("E"), "ts": now, "ev": ev, "d": d}
	var box: Array = acct(id).inbox
	box.append(e)
	while box.size() > rules.num("inbox_max"):
		box.pop_front()
	events.append([id, e.duplicate(true)])

func name_of(id: int) -> String:
	return str(acct(id).get("name", ""))

## Integral floats become ints, StringNames strings, keys strings: the one canonical shape
## shared by live state and state reloaded from JSON.
static func norm(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			if is_finite(f) and f == floorf(f) and absf(f) <= 9007199254740991.0:
				return int(f)
			return f
		TYPE_STRING_NAME:
			return str(v)
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[str(k)] = norm(v[k])
			return out
		TYPE_ARRAY:
			var out: Array = []
			for x in v:
				out.append(norm(x))
			return out
	return v

static func canon(state: Dictionary) -> String:
	return JSON.stringify(state, "", true, true)
