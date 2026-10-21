class_name MarketSell
extends Control
## The Sell tab (spec 06 seller flow): pick one exact instance of the SERVER character (its bag,
## its bonded pets, or what waits in its market storage; never the local single-player bag, A12),
## set the price, read the preview, List. List = vault.deposit of that instance (its bag slot is
## re-read by uid right before, so a moved stack is never the one that leaves) and then
## market.list_fixed of the uid the deposit answered; stored items skip the deposit. If the
## second step fails the item is safe in market storage and shows there to list again.

signal listed(res: Dictionary)
signal loaded ## after every reload of the picker (tests and the lab wait on it)

const FEE_SHORT := "Not enough T-stones for the listing fee."
const EMPTY := "Your bag on this server is empty. What you gather, craft, capture or tame online can be sold here."

var client: MarketClient
var picker: MarketPicker
var form: MarketSellForm
var entries: Array = []
var selected := "" ## uid of the picked entry
var _m := {}

func _ready() -> void:
	picker = MarketPicker.new()
	picker.name = "Picker"
	picker.picked.connect(select)
	add_child(picker)
	form = MarketSellForm.new()
	form.list_pressed.connect(list_selected)
	add_child(form)

## Opens the tab; `uid` preselects an instance (INVUI's "Sell on Market").
func start(p_client: MarketClient, uid: String = "") -> void:
	client = p_client
	selected = uid
	await reload()

## Every T-stone the account holds: a listing fee is a sink, so bound ones pay it too. `lock_s`:
## wallet.get's trade_lock_s (hook H6), the seconds before a new account may trade; until then
## List stays off, so nothing leaves the bag for a listing the server would refuse.
func set_wallet(n: int, lock_s: int = 0) -> void:
	form.wallet = n
	form.lock_s = lock_s
	form.refresh()

## Reads the server character and its market storage again and rebuilds the picker.
func reload() -> void:
	if client == null:
		return
	var ch: Dictionary = await client.request("char.get")
	var vault: Dictionary = await client.request("vault.get")
	if not ch.get("ok", false):
		entries = []
		picker.show_entries([], "", MarketFormat.error_text(ch))
		form.show_entry({})
		loaded.emit()
		return
	entries = MarketFormat.sell_entries(ch.r, vault.r if vault.get("ok", false) else {})
	if current().is_empty():
		selected = ""
	picker.show_entries(entries, selected, EMPTY)
	await select(selected)
	loaded.emit()

func current() -> Dictionary:
	for e: Dictionary in entries:
		if selected != "" and str(e.uid) == selected:
			return e
	return {}

func select(uid: String) -> void:
	selected = uid
	picker.set_selected(uid)
	var e := current()
	form.show_entry(e)
	if not _m.is_empty():
		layout(_m, Rect2(position, size)) # a stack's Quantity row changes the width the panel wants
	if e.is_empty() or str(e.why) != "":
		return
	var key := {"species": str(e.asset.get("species", ""))} if e.kind == "pet" else {"def_id": str(e.asset.get("id", ""))}
	var res: Dictionary = await client.request("market.item_detail", key)
	if selected == uid and res.get("ok", false):
		form.set_reference(res.r)

## vault.deposit (unless it is already stored) then market.list_fixed, one rid each; a second tap
## while pending does nothing.
func list_selected() -> void:
	var e := current()
	if e.is_empty() or not form.can_list():
		return
	var unit := form.unit
	var count := form.count
	var hours := form.hours
	form.set_pending(true, "Listing…")
	var uid := str(e.uid)
	var stored: bool = e.src == "vault"
	if not stored:
		var dep_args := {"pet_uid": uid}
		if e.kind == "item":
			var slot := await _slot_now(uid)
			if slot < 0:
				await _finish("That item is no longer in your bag.", "")
				return
			dep_args = {"bag_slot": slot, "count": count}
		var dep: Dictionary = await client.request("vault.deposit", dep_args)
		if not dep.get("ok", false):
			await _finish(MarketFormat.error_text(dep), uid)
			return
		uid = str(dep.r.uid) # part of a stack leaves under a new uid
		stored = true
	var res: Dictionary = await client.request("market.list_fixed", {"asset": {"uid": uid, "count": count}, "unit_price": unit, "duration_h": hours})
	if not res.get("ok", false):
		var why := FEE_SHORT if str(res.get("err", "")) == "insufficient_funds" else MarketFormat.error_text(res)
		await _finish(why + " It is safe in your market storage: list it again here, or take it back with Receive All in My Market.", uid)
		return
	listed.emit(res)
	selected = ""
	await reload()
	form.say("Listed %s for %s T-stones (fee %s paid). It shows in My Market under Active until it sells or expires." % [e.name + ("  ×%d" % count if count > 1 else ""), MarketFormat.group(unit * count), MarketFormat.group(int(res.r.get("fee", 0)))], MarketTheme.GOLD)

## The bag slot that holds `uid` right now (char.get), or -1.
func _slot_now(uid: String) -> int:
	var ch: Dictionary = await client.request("char.get")
	var bag: Array = ch.get("r", {}).get("bag", [])
	for i in bag.size():
		if bag[i] is Dictionary and str(bag[i].get("uid", "")) == uid:
			return i
	return -1

## A refusal: the picker shows where things are now, the failed entry stays picked, the reason stays.
func _finish(text: String, keep_uid: String) -> void:
	selected = keep_uid
	await reload()
	form.say(text, MarketTheme.DANGER)

func layout(m: Dictionary, rect: Rect2) -> void:
	_m = m
	position = rect.position
	size = rect.size
	form.fit(m)
	var pw := clampf(roundf(size.x * (0.52 if m.compact else 0.4)), 300.0, 580.0)
	pw = minf(maxf(pw, ceilf(form.one_line_width())), roundf(size.x * 0.6)) # the picker keeps 40 %
	picker.layout(m, Rect2(0, 0, size.x - pw - m.margin, size.y))
	form.position = Vector2(size.x - pw, 0)
	form.size = Vector2(pw, size.y)
