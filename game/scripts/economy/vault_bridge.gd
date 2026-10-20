class_name VaultBridge
extends RefCounted
## The one path between a server-owned character (CharacterStore, contract v2 section 0) and the
## economy (EconStore). Assets move only through the character store's own ops:
## act.deposit hands an asset to the vault, char.receive takes back the exact body it exported,
## char.grant takes back units the books split off an export, char.settled drops an export the
## books split or consumed, char.wallet mirrors the ledger.
## The two stores journal separately. A deposit or a grant is marked in the economy first
## (bridge.begin: account, rid, uid), and recover() finishes or undoes exactly that move; a
## whole-asset withdrawal runs char.receive first, so a held export the character store no
## longer lists was received. recover() runs at boot and right after any move that could not
## finish; until it succeeds the bridge refuses every op, so nothing in two places is traded.
## Single writer: call client() / apply() on the server's main thread, one request at a time.

## Economy ops the transport may relay from a client; client() adds the character intents a
## client may send (IntentHandlers.CLIENT_OPS). Everything else is server-only.
const CLIENT_OPS := MarketEngine.READ + MarketEngine.WRITE + ["vault.deposit", "vault.withdraw"]

var econ: EconStore
var chars: CharacterStore
var broken := "" ## a move the stores could not finish; every op first retries recover()

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

## The transport's one entry for a client frame: economy ops go to apply(), the intents a client
## may send go to the character store, and anything else (act.deposit, char.receive, char.grant,
## bridge.*, objective.claim, ...) is refused and logged, never relayed.
func client(op: String, account: int, args: Dictionary, ts: int) -> Dictionary:
	if op in CLIENT_OPS:
		return apply(op, account, args, ts)
	if op not in IntentHandlers.CLIENT_OPS:
		push_warning("[econ] refused server-only op %s from account %d" % [op, account])
		return EconArgs.no("unauthorized", "%s is server-only" % op)
	if broken != "" and recover(ts) != "":
		return _stalled()
	return chars.apply(op, account, args, ts)

## Client ops (CLIENT_OPS) and the server's own: sys.tick as account 0, objective.claim when the
## server observed the objective. Responses are the economy's shapes; vault.deposit /
## vault.withdraw answer like vault.deposit_* / withdraw_*.
func apply(op: String, account: int, args: Dictionary, ts: int) -> Dictionary:
	if broken != "" and recover(ts) != "":
		return _stalled()
	var res := _route(op, account, args, ts)
	if broken != "":
		recover(ts) # finish the cut move now, not at the next boot
	return res

func _stalled() -> Dictionary:
	return EconArgs.no("server_error", "the vault bridge is finishing a move: %s" % broken)

func _route(op: String, account: int, args: Dictionary, ts: int) -> Dictionary:
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
	var a := EconArgs.new(args)
	var take := {}
	var preview: Variant = null
	var uid := "" ## the uid act.deposit will export, so recover() claims that asset and no other
	var kind := "pet" if args.has("pet_uid") else "item"
	if kind == "pet":
		uid = a.text("pet_uid", 1, 64)
		if a.err != "":
			return a.fail()
		take = {"pet_uid": uid}
		preview = ch.d.pets.get(uid)
	else:
		var bag: Array = ch.d.bag
		var slot := a.integer("bag_slot", 0, bag.size() - 1)
		var n := a.integer("count", 1, 1000000, 1000000)
		if a.err != "":
			return a.fail()
		take = {"bag_slot": slot, "count": n}
		var row: Variant = bag[slot]
		if row is Dictionary and str(row.id) != str(CharacterState.LOCK):
			preview = (row as Dictionary).duplicate(true)
			preview.count = mini(n, int(row.count))
			# A whole stack leaves under its own uid; a part gets the first uid of the act.deposit op.
			uid = str(row.get("uid", "")) if n >= int(row.count) else Provenance.item_uid(int(chars.s.seq) + 1, 0)
	if not preview is Dictionary:
		return EconArgs.no("not_found", "no such pet or bag slot on your character")
	var no := econ.engine.deposit_refusal(me, kind, preview)
	if not no.is_empty():
		return no
	var begun := econ.apply("bridge.begin", me, {"rid": args.rid, "uid": uid, "op": "deposit"}, ts)
	if not begun.ok:
		return begun
	var out := chars.apply("act.deposit", me, take, ts)
	if not out.ok:
		_end(ts)
		return out
	return _into_vault(me, str(args.rid), out.r.asset, ts)

## Second half of a deposit (also recovery): the exported asset into the vault, or back to the
## character when the vault refuses it after all. If both refuse, the mark stays for recover().
func _into_vault(me: int, rid: String, asset: Dictionary, ts: int) -> Dictionary:
	var pet := str(asset.uid).begins_with("p")
	var res := econ.apply("vault.deposit_pet" if pet else "vault.deposit_item", me, {"rid": rid, "pet_dict" if pet else "slot_dict": asset}, ts)
	if not res.ok:
		var back := chars.apply("char.receive", me, {"asset": asset}, ts)
		if not back.ok:
			broken = "%s is in no vault (the vault said %s, char.receive %s)" % [asset.uid, res.get("err", ""), back.get("err", "")]
			return res
		_end(ts)
	_after(me, ts)
	return res

## vault.withdraw {rid, uid, count?}: vault units back to the account's server character.
## The whole of an exported asset goes through char.receive (the exact body, its own uid),
## which runs first: a crash before the vault lets go is finished by recover(). Anything else
## (a stack the books split, a remainder, part of a stack) goes through char.grant.
func _withdraw(me: int, args: Dictionary, ts: int) -> Dictionary:
	if chars.character(me) == null:
		return EconArgs.no("unauthorized", "account %d has no server character" % me)
	var a := EconArgs.new(args)
	var uid := a.text("uid", 2, 64)
	var want := a.integer("count", 1, 1000000, 0) ## 0: the whole stack
	if a.err != "":
		return a.fail()
	var acct := _books().acct(me)
	var pet: bool = acct.vault_pets.has(uid)
	if not (pet or acct.vault_items.has(uid)):
		return EconArgs.no("not_found", "%s is not in your vault" % uid)
	var held := 1 if pet else int(acct.vault_items[uid].count)
	var n := want if want > 0 else held
	if n > held:
		return EconArgs.no("insufficient_items", "%s holds %d" % [uid, held])
	if _books().s.src.has(uid) and n == held:
		var got := chars.apply("char.receive", me, {"asset": acct.vault_pets[uid] if pet else acct.vault_items[uid]}, ts)
		if not got.ok:
			return got
		return _out_of_vault(me, str(args.rid), uid, pet, ts)
	if pet: # pets are never split, so every vault pet is an export
		return EconArgs.no("not_withdrawable", "%s is not a pet this server exported" % uid)
	return _grant(me, str(args.rid), uid, n, ts)

func _out_of_vault(me: int, rid: String, uid: String, pet: bool, ts: int) -> Dictionary:
	var res := econ.apply("vault.withdraw_pet" if pet else "vault.withdraw_item", me, {"rid": rid, "uid": uid}, ts)
	if not res.ok:
		# The character holds it now; nobody may list or sell the vault copy until this finishes.
		broken = "%s reached the character but is still in the vault (%s)" % [uid, res.get("err", "")]
	_after(me, ts)
	return res

## Units the books made (a split part, a remainder) or part of a stack: the vault lets go of
## exactly those units, then char.grant gives them to the character. The mark comes first and
## the units stay in the rid's cached response, so recover() can finish a grant a crash cut.
func _grant(me: int, rid: String, uid: String, n: int, ts: int) -> Dictionary:
	var part: Dictionary = _books().acct(me).vault_items[uid].duplicate(true)
	part.count = n
	if chars.character(me).inventory().add(ItemStack.from_dict(Provenance.strip(part))) > 0:
		return EconArgs.no("bag_full", "no room in the bag for %d %s" % [n, part.id])
	var begun := econ.apply("bridge.begin", me, {"rid": rid, "uid": uid, "op": "grant"}, ts)
	if not begun.ok:
		return begun
	var res := econ.apply("vault.withdraw_item", me, {"rid": rid, "uid": uid, "count": n}, ts)
	if not res.ok:
		_end(ts)
		return res
	_grant_out(me, rid, ts)
	_after(me, ts)
	return res

## Second half of a grant (also recovery): the units vault.withdraw_item let go of under `rid`
## reach the character exactly once (char.grant's own rid is that withdrawal's seq).
func _grant_out(me: int, rid: String, ts: int) -> void:
	var hit: Array = _books().acct(me).rid_cache.get(rid, [])
	if hit.size() > 2 and str(hit[0]) == "vault.withdraw_item":
		var units: Dictionary = hit[2].r.item
		var got := chars.apply("char.grant", me, {"asset": units, "rid": "g%d" % int(hit[1])}, ts)
		if not got.ok:
			broken = "%d %s left the vault under %s but char.grant refused them (%s)" % [int(units.count), units.id, rid, got.get("err", "")]
			return
	_end(ts) # granted, or the vault never let go

func _end(ts: int) -> void:
	var res := econ.apply("bridge.end", Ledger.SETTLERS, {}, ts)
	if not res.ok:
		broken = "bridge.end failed (%s)" % res.get("err", "")

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

## Boot, and any time a move could not finish: finishes or undoes the one marked move (for its
## account and uid only), takes a received export out of the vault, settles retired exports,
## mirrors every wallet, and reports any export in no vault (it left a character outside this
## bridge, so no owner is guessed). Returns "" or why the books need a person.
func recover(ts: int) -> String:
	broken = ""
	var books := _books()
	var exported: Dictionary = chars.s.exported_assets
	var f: Dictionary = books.s.inflight.duplicate()
	if not f.is_empty():
		var uid := str(f.get("uid", ""))
		if str(f.get("op", "")) == "grant":
			_grant_out(int(f.account), str(f.rid), ts)
		elif exported.has(uid) and not books.s.src.has(uid) and not books.s.retired.has(uid):
			_into_vault(int(f.account), str(f.rid), JSON.parse_string(exported[uid]), ts)
		else:
			_end(ts) # act.deposit never ran, or its asset already came back
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
	var marked := str(books.s.inflight.get("uid", ""))
	var lost := exported.keys().filter(func (u: String) -> bool: return u != marked and not books.s.src.has(u) and not books.s.retired.has(u))
	if broken == "" and not lost.is_empty():
		broken = "%d exports are in no vault (%s); only VaultBridge may run act.deposit" % [lost.size(), ", ".join(lost)]
	return broken
