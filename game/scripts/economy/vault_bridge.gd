class_name VaultBridge
extends RefCounted
## The one path between a server-owned character (CharacterStore, contract v2 section 0) and the
## economy (EconStore). Assets move only through the character store's own ops:
## act.deposit hands an asset to the vault, char.receive takes back the exact body it exported,
## char.settled drops an export the books split or consumed, char.wallet mirrors the ledger.
## The two stores journal separately, so recover() finishes or undoes a move a crash cut in
## half: a deposit is marked in the economy first (bridge.begin), and a withdrawal runs
## char.receive first, so a held export the character store no longer lists was received.
## Single writer: call apply() on the server's main thread, one request at a time.

## What the transport may relay from a client; everything else is server-only.
const CLIENT_OPS := MarketEngine.READ + MarketEngine.WRITE + ["vault.deposit", "vault.withdraw"]

var econ: EconStore
var chars: CharacterStore

func _init(p_econ: EconStore, p_chars: CharacterStore) -> void:
	econ = p_econ
	chars = p_chars

func _books() -> Ledger:
	return econ.engine.L

## auth.hello: the economy account and the server character, created once, wallets in step.
func hello(account: int, name: String, ts: int) -> Dictionary:
	var e := econ.apply("account.ensure", account, {"name": name}, ts)
	if not e.ok:
		return e
	var c := chars.apply("char.create", account, {"name": name}, ts)
	if not c.ok:
		return c
	_mirror(account, ts)
	return e

## Client ops (CLIENT_OPS) and the server's own (sys.tick, account 0). Responses are the
## economy's shapes; vault.deposit / vault.withdraw answer like vault.deposit_* / withdraw_*.
func apply(op: String, account: int, args: Dictionary, ts: int) -> Dictionary:
	if op == "vault.deposit" or op == "vault.withdraw":
		var cached := _repeat(op, account, args, ts)
		if not cached.is_empty():
			return cached
		return _deposit(account, args, ts) if op == "vault.deposit" else _withdraw(account, args, ts)
	if op in MarketEngine.BRIDGE or op.begins_with("bridge."):
		return EconArgs.no("unauthorized", "%s is server-only" % op)
	var res := econ.apply(op, account, args, ts)
	_after(account, ts)
	return res

## A rid the books already hold answers from their cache (the same body after any restart);
## a rid used for another op is a conflict. {} means the rid is new.
func _repeat(op: String, account: int, args: Dictionary, ts: int) -> Dictionary:
	var rid: Variant = args.get("rid")
	if not (rid is String and (rid as String).length() >= 1 and (rid as String).length() <= 64):
		return EconArgs.no("bad_request", "rid must be 1..64 characters")
	if _books().acct(account).is_empty():
		return EconArgs.no("unauthorized", "unknown account")
	var hit: Array = _books().acct(account).rid_cache.get(rid, [])
	if hit.is_empty():
		return {}
	if not str(hit[0]).begins_with(op + "_"): # vault.deposit -> vault.deposit_item / _pet
		return EconArgs.no("conflict", "rid already used for %s" % str(hit[0]))
	return econ.apply(str(hit[0]), account, {"rid": rid}, ts)

## vault.deposit {rid, bag_slot, count?} | {rid, pet_uid}: an asset of the account's server
## character into its vault. Everything is checked before bridge.begin: the books are asked
## first, so the character loses nothing the vault would refuse.
func _deposit(me: int, args: Dictionary, ts: int) -> Dictionary:
	var ch := chars.character(me)
	if ch == null:
		return EconArgs.no("unauthorized", "account %d has no server character" % me)
	for k: String in args:
		if k not in ["rid", "bag_slot", "count", "pet_uid"]:
			return EconArgs.no("invalid_asset", "deposits take a bag slot or a pet uid of your character, not %s" % k)
	var take := {}
	var preview: Variant = null
	var kind := "item"
	if args.has("pet_uid"):
		kind = "pet"
		take = {"pet_uid": args.pet_uid}
		preview = ch.d.pets.get(args.pet_uid) if args.pet_uid is String else null
	else:
		var slot: Variant = EconArgs.as_int(args.get("bag_slot"))
		var n: Variant = EconArgs.as_int(args.get("count", 1000000))
		var bag: Array = ch.d.bag
		var row: Variant = bag[int(slot)] if slot != null and int(slot) >= 0 and int(slot) < bag.size() else null
		take = {"bag_slot": slot, "count": n}
		if row is Dictionary and str(row.id) != str(CharacterState.LOCK) and n != null and int(n) >= 1:
			preview = (row as Dictionary).duplicate(true)
			preview.count = mini(int(n), int(row.count))
	if not preview is Dictionary:
		return EconArgs.no("not_found", "no such pet, bag slot or count on your character")
	var no := econ.engine.deposit_refusal(me, kind, preview)
	if not no.is_empty():
		return no
	var begun := econ.apply("bridge.begin", me, {"rid": args.rid}, ts)
	if not begun.ok:
		return begun
	var out := chars.apply("act.deposit", me, take, ts)
	if not out.ok:
		econ.apply("bridge.end", Ledger.SETTLERS, {}, ts)
		return out
	return _into_vault(me, str(args.rid), out.r.asset, ts)

## Second half of a deposit (also boot recovery): the exported asset into the vault, or back
## to the character when the vault refuses it after all.
func _into_vault(me: int, rid: String, asset: Dictionary, ts: int) -> Dictionary:
	var pet := str(asset.uid).begins_with("p")
	var res := econ.apply("vault.deposit_pet" if pet else "vault.deposit_item", me, {"rid": rid, "pet_dict" if pet else "slot_dict": asset}, ts)
	if not res.ok:
		var back := chars.apply("char.receive", me, {"asset": asset}, ts)
		if not back.ok:
			push_error("[econ] %s refused by the vault and by char.receive (%s); recover() retries at boot" % [asset.uid, back.get("err", "")])
			return res
		econ.apply("bridge.end", Ledger.SETTLERS, {}, ts)
	_after(me, ts)
	return res

## vault.withdraw {rid, uid}: a whole vault asset back to the account's server character.
## char.receive takes only bodies the character store exported, byte for byte; a part of a
## split stack stays in the vault until the store has an economy-mint op (see the report).
## char.receive runs first: a crash before the vault lets go is finished by recover().
func _withdraw(me: int, args: Dictionary, ts: int) -> Dictionary:
	if chars.character(me) == null:
		return EconArgs.no("unauthorized", "account %d has no server character" % me)
	var uid: Variant = args.get("uid")
	var acct := _books().acct(me)
	var pet: bool = uid is String and acct.vault_pets.has(uid)
	if not (uid is String and (pet or acct.vault_items.has(uid))):
		return EconArgs.no("not_found", "%s is not in your vault" % str(uid))
	if not _books().s.src.has(uid):
		return EconArgs.no("not_withdrawable", "%s was split or bought in part; it stays in the vault until the server can mint it back" % uid)
	var body: Dictionary = acct.vault_pets[uid] if pet else acct.vault_items[uid]
	var got := chars.apply("char.receive", me, {"asset": body}, ts)
	if not got.ok:
		return got
	return _out_of_vault(me, str(args.rid), str(uid), pet, ts)

func _out_of_vault(me: int, rid: String, uid: String, pet: bool, ts: int) -> Dictionary:
	var res := econ.apply("vault.withdraw_pet" if pet else "vault.withdraw_item", me, {"rid": rid, "uid": uid}, ts)
	if not res.ok:
		push_error("[econ] %s reached the character but not out of the vault (%s); recover() retries at boot" % [uid, res.get("err", "")])
	_after(me, ts)
	return res

## After every economy op: retired exports are settled in the character store, and every
## wallet the op moved is mirrored to its character.
func _after(me: int, ts: int) -> void:
	var touched := _books().touched.keys()
	_settle(me, ts)
	for id: int in touched:
		_mirror(id, ts)

func _settle(me: int, ts: int) -> void:
	var retired: Array = _books().s.retired.keys()
	if retired.is_empty():
		return
	# char.settled reads no character, but CharacterStore runs ops as one; any account will do.
	var who := me if chars.character(me) != null else (int(chars.s.chars.keys()[0]) if not chars.s.chars.is_empty() else 0)
	for uid: String in retired:
		var r := chars.apply("char.settled", who, {"uid": uid}, ts)
		if not r.ok and r.err != "not_found": # not_found: settled before a crash cut this loop
			push_error("[econ] char.settled %s: %s" % [uid, r.err])
			return
	econ.apply("bridge.settled", Ledger.SETTLERS, {"uids": retired}, ts)

func _mirror(id: int, ts: int) -> void:
	if id >= 1 and chars.character(id) != null and not _books().acct(id).is_empty():
		chars.apply("char.wallet", id, {"wallet": int(_books().acct(id).wallet)}, ts)

## Boot, after both stores open(): finishes or undoes the move a crash cut in half, settles
## retired exports, and mirrors every wallet. Returns "" or why the books need a person.
func recover(ts: int) -> String:
	var why := ""
	var books := _books()
	var exported: Dictionary = chars.s.exported_assets
	var f: Dictionary = books.s.inflight.duplicate()
	if not f.is_empty():
		# act.deposit ran iff an export is neither in the books nor retired; one op runs at a time.
		var orphans := exported.keys().filter(func (u: String) -> bool: return not books.s.src.has(u) and not books.s.retired.has(u))
		if orphans.size() == 1:
			_into_vault(int(f.account), str(f.rid), JSON.parse_string(exported[orphans[0]]), ts)
		elif orphans.size() > 1:
			why = "%d exports are in no vault (%s); act.deposit must only run through VaultBridge" % [orphans.size(), ", ".join(orphans)]
		econ.apply("bridge.end", Ledger.SETTLERS, {}, ts)
	# A held export the character store no longer lists came back through char.receive.
	for uid: String in books.s.src.keys():
		if exported.has(uid):
			continue
		for key: String in books.s.accounts:
			var acct: Dictionary = books.s.accounts[key]
			if acct.vault_items.has(uid) or acct.vault_pets.has(uid):
				_out_of_vault(int(key), "recover-" + uid, uid, acct.vault_pets.has(uid), ts)
				break
	_settle(0, ts)
	for key: String in chars.s.chars:
		_mirror(int(key), ts)
	return why
