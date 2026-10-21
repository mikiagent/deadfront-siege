class_name IntentHandlers
extends RefCounted
## The server half of contract v2 §0.3: one handler per act.<verb>, run on the server-side
## character with the game's own domain classes (Inventory, Crafting, Food, PetRecord,
## ProgressionScaling) against a WorldFacade. Each handler validates everything first and
## returns an error with nothing changed, or mutates and returns ok. Chance comes only from
## `rng` (ServerRng, seeded by the op's seq). Every world read goes through _read(), which
## records it on `tape`; a replay hands the tape back instead of asking the island.
# ASSUMPTION: error codes beyond contract §2 (out_of_range, depleted, missing_tool, bag_full,
# not_ready) are new stable strings for intents; the orchestrator adds them to the contract.

const CLIENT_OPS := ["act.gather", "act.loot", "act.craft", "act.place", "act.equip", "act.eat", "act.tame", "act.capture", "act.attack", "char.import", "char.get"]
## The server itself, never relayed from a client. act.deposit runs only inside VaultBridge
## (clients send vault.deposit), so an asset never leaves a character without a vault to take it.
const SYSTEM_OPS := ["char.create", "char.move", "char.wallet", "char.receive", "char.settled", "char.grant", "act.deposit"]
const READ_OPS := ["char.get"]
const GATHER_REACH := PlayerInput.INTERACT_GATHER_RANGE ## 2.6 m, the client's own gather reach
const LOOT_REACH := 2.6 ## Player corpse reach
## ASSUMPTION: latency allowance on top of a creature's body reach. Deliberately wider than the
## client's own swing check (combat_tuning hit_reach_slack_m 0.3): the server judges a position
## that is a presence update old.
const REACH_SLACK := 0.5
const RUN_SPEED := 7.0 ## ASSUMPTION: Player.run_speed (an export var, so not a constant there)
## Request fields that carry an asset dict. Online characters only move assets by slot or uid.
const ASSET_DICT_KEYS := ["slot_dict", "pet_dict", "item", "pet", "stack", "asset", "save", "bag", "pets"]
## The args each op reads. CharacterStore.apply() keeps only these (and rid) before the op runs
## and is journaled, so junk keys can neither reach a handler nor grow the journal. act.deposit
## keeps the asset-dict keys only to refuse them.
const ARG_KEYS := {
	"act.gather": ["node_id", "option"], "act.loot": ["corpse_id", "slot", "count"],
	"act.craft": ["recipe_id", "picks"], "act.place": ["kind", "cell", "rot"],
	"act.equip": ["bag_slot", "slot", "clear"], "act.eat": ["bag_slot"],
	"act.tame": ["net_id", "food"], "act.capture": ["net_id"], "act.attack": ["net_id"],
	"act.deposit": ["bag_slot", "count", "pet_uid", "slot_dict", "pet_dict", "item", "pet", "stack", "asset", "save", "bag", "pets"],
	"char.import": [], "char.get": [], "char.create": ["name"], "char.move": ["p", "reset"],
	"char.wallet": ["wallet"], "char.receive": ["asset"], "char.settled": ["uid"], "char.grant": ["asset"],
}

var world: WorldFacade
var s: Dictionary         ## CharacterStore state, for the minted/consumed/exported counters
var seq := 0              ## the seq this op is journaled under if it commits
var now := 0
var account := 0
var rng: RandomNumberGenerator
var tape: Array = []
var writes: Array = []    ## world writes of this op, applied by flush() only once it commits
var replaying := false
var _tape_i := 0

func _init(p_world: WorldFacade) -> void:
	world = p_world

func begin(p_state: Dictionary, p_seq: int, p_now: int, p_account: int, op: String, p_tape: Array, p_replaying: bool) -> void:
	s = p_state
	seq = p_seq
	now = p_now
	account = p_account
	rng = ServerRng.for_op(int(s.world_seed), seq, op)
	tape = p_tape
	replaying = p_replaying
	_tape_i = 0
	writes.clear()

func run(op: String, ch: CharacterState, a: Dictionary) -> Dictionary:
	match op:
		"act.gather": return _gather(ch, a)
		"act.loot": return _loot(ch, a)
		"act.craft": return _craft(ch, a)
		"act.place": return _place(ch, a)
		"act.equip": return _equip(ch, a)
		"act.eat": return _eat(ch, a)
		"act.tame": return _tame(ch, a)
		"act.capture": return _capture(ch, a)
		"act.attack": return _attack(ch, a)
		"act.deposit": return _deposit(ch, a)
		"char.import": return no("invalid_asset", "offline saves never import into online characters")
		"char.get": return ok(ch.view(), false)
		"char.move": return _move(ch, a)
		"char.wallet": return _wallet(ch, a)
		"char.receive": return _receive(ch, a)
		"char.settled": return _settled(a)
		"char.grant": return _grant(ch, a)
	return no("bad_request", "unknown op %s" % op)

# --- intents -----------------------------------------------------------------------------

## act.gather {node_id, option}: one pass on a harvest node, as Player._finish_gather does it.
func _gather(ch: CharacterState, a: Dictionary) -> Dictionary:
	var node_id: Variant = text(a, "node_id")
	var opt: Variant = integer(a, "option", 0, 31, 0)
	if node_id == null or opt == null:
		return no("bad_request", "node_id (string) and option (0..31) are required")
	var n := _read("node", [node_id])
	if n.is_empty():
		return no("not_found", "no node %s" % node_id)
	var options: Array = n.get("options", [])
	if int(opt) >= options.size():
		return no("bad_request", "node %s has %d options" % [node_id, options.size()])
	var o: Dictionary = options[int(opt)]
	var def := Data.item(StringName(str(o.get("item", ""))))
	if def == null:
		return no("not_found", "node %s yields an unknown item" % node_id)
	if ch.pos().distance_to(WorldFacade.v3(n.get("pos"))) > GATHER_REACH:
		return no("out_of_range", "node %s is beyond %.1f m" % [node_id, GATHER_REACH])
	if int(o.get("left", 0)) <= 0:
		return no("depleted", "no %s left on %s" % [def.id, node_id])
	var inv := ch.inventory()
	var tool_class := StringName(str(o.get("tool", "none")))
	if not inv.has_tool_class(tool_class):
		return no("missing_tool", "needs a %s" % tool_class)
	var tool := inv.find_gather_tool(tool_class)
	if tool and not inv.wear_gather_tool(tool_class):
		ch.commit(inv, "gather", seq) # the tool broke on this pass: the wear stands, nothing is gathered
		return ok({"broke": str(tool.def_id), "gained": 0})
	var attrs: Dictionary = n.get("attributes", {})
	var zone := int(attrs.get("level", n.get("level", 1)))
	var stack := ItemStack.make(def.id, rng.randi_range(int(o.get("min", 1)), int(o.get("max", 1))), attrs, zone)
	if bool(n.get("unstable", false)):
		stack.set_flag(&"unstable", true)
	var mult := ProgressionScaling.gather_yield_multiplier(zone, tool.level if tool else 1, tool.material_tier() if tool else &"stone", maxi(1, ch.level_of("gathering")))
	stack.count = maxi(1, int(floor(float(stack.count) * mult)))
	if rng.randf() < fmod(mult, 1.0):
		stack.count += 1
	var cap := maxi(ch.level_of("gathering"), 5) # rules.json gathering_downrank, floor 5 as on the client
	if stack.level > cap:
		stack.level = cap
		stack.attributes["level"] = cap
	var before := stack.count
	var gained := before - inv.add(stack)
	if gained <= 0:
		return no("bag_full", "bag is full")
	_write("take_node_unit", [node_id, str(def.id)])
	var uids := ch.commit(inv, "gather", seq)
	count("minted", def.id, gained)
	ch.add_xp("gathering", 2)
	if str(n.get("family", "")).begins_with("Rock") or str(n.get("family", "")) == "clay":
		ch.add_xp("processing", 1)
	return ok({"item": str(def.id), "gained": gained, "uids": uids})

## act.loot {corpse_id, slot, count?}: move a corpse slot (or part of it) into the bag.
func _loot(ch: CharacterState, a: Dictionary) -> Dictionary:
	var corpse_id: Variant = text(a, "corpse_id")
	var slot: Variant = integer(a, "slot", 0, 255)
	var want: Variant = integer(a, "count", 1, 1000000, 1000000)
	if corpse_id == null or slot == null or want == null:
		return no("bad_request", "corpse_id, slot (0..255) and an optional count >= 1 are required")
	var c := _read("corpse", [corpse_id])
	if c.is_empty():
		return no("not_found", "no corpse %s" % corpse_id)
	var slots: Array = c.get("slots", [])
	if int(slot) >= slots.size() or not slots[int(slot)] is Dictionary:
		return no("not_found", "corpse %s slot %d is empty" % [corpse_id, slot])
	if ch.pos().distance_to(WorldFacade.v3(c.get("pos"))) > LOOT_REACH:
		return no("out_of_range", "corpse %s is beyond %.1f m" % [corpse_id, LOOT_REACH])
	var stack := ItemStack.from_dict(Provenance.strip(slots[int(slot)]))
	if stack.def() == null or stack.count <= 0:
		return no("not_found", "corpse %s slot %d holds nothing lootable" % [corpse_id, slot])
	stack.count = mini(stack.count, int(want))
	var inv := ch.inventory()
	var gained := stack.count - inv.add(stack)
	if gained <= 0:
		return no("bag_full", "bag is full")
	_write("take_corpse", [corpse_id, int(slot), gained])
	var uids := ch.commit(inv, "loot", seq)
	count("minted", stack.def_id, gained)
	return ok({"item": str(stack.def_id), "gained": gained, "uids": uids})

## act.craft {recipe_id, picks?}: Crafting's own plan, consume and build_output on the server bag.
func _craft(ch: CharacterState, a: Dictionary) -> Dictionary:
	var rid: Variant = text(a, "recipe_id")
	if rid == null:
		return no("bad_request", "recipe_id is required")
	var rec := Crafting.recipe(StringName(str(rid)))
	if rec.is_empty():
		return no("not_found", "no recipe %s" % rid)
	var tree := str(rec.get("skill", "processing"))
	var survival := int(rec.get("required_survival", 0))
	if survival > 0 and ch.level_of("survival") < survival:
		return no("not_ready", "needs Survival %d" % survival)
	var minimum := int(rec.get("min_level", 0))
	if minimum > 0 and ch.level_of(tree) < minimum:
		return no("not_ready", "needs %s %d" % [tree, minimum])
	var sid := Crafting.station_id(rec)
	if sid != "" and not bool(_read("station_near", [sid, ch.d.pos, Crafting.STATION_RANGE]).get("ok", false)):
		return no("out_of_range", "needs a %s within %.1f m" % [sid, Crafting.STATION_RANGE])
	var inv := ch.inventory()
	var picks: Array[int] = []
	var raw: Variant = a.get("picks")
	if raw == null:
		picks = Crafting.default_picks(inv, rec)
	elif raw is Array and (raw as Array).size() == (rec.get("slots", []) as Array).size():
		for p in raw:
			# Crafting indexes the slot's def directly, so refuse empties and multi-slot locks here.
			if not p is int or int(p) < 0 or int(p) >= inv.slot_count or inv.slots[int(p)] == null or inv.slots[int(p)].def() == null:
				return no("insufficient_items", "picks must point at bag slots holding materials")
			picks.append(int(p))
	else:
		return no("bad_request", "picks must list one bag slot per recipe slot")
	if not Crafting.picks_valid(inv, rec, picks):
		return no("insufficient_items", "missing %s" % Crafting.missing_ingredient_name(inv, rec))
	# Monotonic in skill (W1-ITEMS drops the client's skill-0 = 60 fallback); level 0 caps at 1.
	var level := ProgressionScaling.crafted_level(Crafting.consumed_levels(inv, rec, picks), int(rec.get("max_level", 60)), maxi(1, ch.level_of(tree)))
	if minimum > 0 and level < minimum:
		return no("not_ready", "needs materials and crafting skill for level %d" % minimum)
	var consumed := Crafting.consume_for_craft(inv, rec, picks)
	var out := Crafting.build_output(rec, consumed[0], level, consumed, Crafting.rolls_burn(rec, ch.level_of(tree), rng))
	var made := out.count
	var out_id := out.def_id
	if out.def() == null or made <= 0:
		return no("server_error", "recipe %s has no valid output" % rid)
	if inv.add(out) > 0:
		return no("bag_full", "no room for %s" % out_id)
	var uids := ch.commit(inv, "craft", seq)
	for part in consumed:
		count("consumed", part.def_id, part.count)
	count("minted", out_id, made)
	ch.add_xp(Crafting.tree_for_recipe(rec), 6 + int(Crafting.recipe_seconds(rec)))
	return ok({"item": str(out_id), "made": made, "level": level, "uids": uids})

## act.place {kind, cell: [x, z], rot}: spends one kit whose place_as is `kind`.
# shortcut: kits only; the branch+twine fallbacks in BuildPlacer move here with W3-SRVACT.
func _place(ch: CharacterState, a: Dictionary) -> Dictionary:
	var kind: Variant = text(a, "kind", 32)
	var cell: Variant = a.get("cell")
	var rot: Variant = integer(a, "rot", 0, 3, 0)
	if kind == null or rot == null or not (cell is Array and (cell as Array).size() == 2 and cell[0] is int and cell[1] is int and absi(cell[0]) < 100000 and absi(cell[1]) < 100000):
		return no("bad_request", "kind, cell [x, z] and rot 0..3 are required")
	var inv := ch.inventory()
	var kit := -1
	for i in inv.slot_count:
		var st := inv.slots[i]
		if st and not st.is_locked() and st.def() and str(st.def().place_as) == kind:
			kit = i
			break
	if kit < 0:
		return no("insufficient_items", "no %s kit in the bag" % kind)
	var why := str(_read("placement", [kind, cell, int(rot), ch.d.pos]).get("why", "?"))
	if why != "":
		return no("conflict", "cannot place %s: %s" % [kind, why])
	var kit_id := inv.slots[kit].def_id
	inv.remove_at(kit, 1)
	var structure_id := "s%d" % seq
	_write("place", [kind, cell, int(rot), account, structure_id])
	ch.commit(inv, "craft", seq)
	count("consumed", kit_id, 1)
	ch.add_xp("construction", 2) # ASSUMPTION: placing a building trains Construction a little
	return ok({"structure_id": structure_id, "kit": str(kit_id)})

## act.equip {bag_slot} equips by uid; {slot, clear: true} empties a slot ("tool" for the gather tool).
func _equip(ch: CharacterState, a: Dictionary) -> Dictionary:
	var clear: Variant = a.get("clear", false)
	if not clear is bool: # bool() on a String or Dictionary is a script error, not a refusal
		return no("bad_request", "clear must be true or false")
	if clear:
		var name: Variant = text(a, "slot", 16)
		if name == null or (StringName(str(name)) not in Inventory.EQUIP_SLOTS and name != "tool"):
			return no("bad_request", "slot must be tool or one of %s" % str(Inventory.EQUIP_SLOTS))
		if name == "tool":
			if str(ch.d.tool) == "":
				return ok({}, false)
			ch.d.tool = ""
		elif not ch.d.equipment.has(name):
			return ok({}, false)
		else:
			ch.d.equipment.erase(name)
		return ok({"cleared": name})
	var i: Variant = integer(a, "bag_slot", 0, (ch.d.bag as Array).size() - 1)
	if i == null:
		return no("bad_request", "bag_slot is required")
	var uid := ch.slot_uid(int(i))
	var row: Variant = ch.d.bag[int(i)]
	var def := Data.item(StringName(str(row.get("id", "")))) if row is Dictionary else null
	if uid == "" or def == null:
		return no("not_found", "bag slot %d is empty" % i)
	if &"locked" in ItemStack.from_dict(row).flags:
		return no("bad_request", "locked items cannot be equipped")
	var slot := str(Inventory.slot_for(def))
	if slot == "":
		if def.tool_class == &"" or def.tool_class == &"none":
			return no("bad_request", "%s cannot be equipped" % def.id)
		if str(ch.d.tool) == uid:
			return ok({"tool": uid}, false)
		ch.d.tool = uid
		return ok({"tool": uid})
	if slot == "accessory1" and str(ch.d.equipment.get("accessory1", "")) not in ["", uid]:
		slot = "accessory2" # Inventory.equip's second accessory rule
	if str(ch.d.equipment.get(slot, "")) == uid:
		return ok({slot: uid}, false)
	ch.d.equipment[slot] = uid
	return ok({slot: uid})

## act.eat {bag_slot}: one unit; energy, buffs and raw risks are returned for the client's vitals.
# ASSUMPTION: vitals (energy, Full, buffs) stay client-side in W1; the server owns the food unit
# and the raw-risk roll.
func _eat(ch: CharacterState, a: Dictionary) -> Dictionary:
	var i: Variant = integer(a, "bag_slot", 0, (ch.d.bag as Array).size() - 1)
	if i == null:
		return no("bad_request", "bag_slot is required")
	var inv := ch.inventory()
	var stack := inv.slots[int(i)]
	if stack == null or stack.def_id == CharacterState.LOCK:
		return no("not_found", "bag slot %d is empty" % i)
	if not Food.is_food(stack):
		return no("bad_request", "%s is not food" % stack.def_id)
	var one := stack.duplicate_stack()
	one.count = 1
	var status := ""
	if Food.is_raw(one):
		var d := one.def()
		if Food.is_poisoned(one) or (d.poison_chance > 0.0 and rng.randf() < d.poison_chance):
			status = "stomachache"
		elif d.tastes_bad_chance > 0.0 and rng.randf() < d.tastes_bad_chance:
			status = "tastes_bad"
	var buffs: Array = []
	for b in Food.buff_ids(one):
		buffs.append(str(b))
	inv.remove_at(int(i), 1)
	ch.commit(inv, "craft", seq)
	count("consumed", one.def_id, 1)
	return ok({"item": str(one.def_id), "energy": Food.energy_restore(one), "buffs": buffs, "status": status})

## act.tame {net_id, food}: one field-tame feed (FieldTame rules); the last feed bonds a pet.
func _tame(ch: CharacterState, a: Dictionary) -> Dictionary:
	var net_id: Variant = text(a, "net_id")
	var food: Variant = text(a, "food", 48)
	if net_id == null or food == null:
		return no("bad_request", "net_id and food are required")
	var c := _read("creature", [net_id])
	if c.is_empty():
		return no("not_found", "no creature %s" % net_id)
	var def := Data.creature(StringName(str(c.get("species", ""))))
	if def == null or not def.tameable or bool(c.get("pet", false)):
		return no("bad_request", "%s cannot be tamed" % net_id)
	if ch.pos().distance_to(WorldFacade.v3(c.get("pos"))) > body_reach(def) + REACH_SLACK:
		return no("out_of_range", "%s is out of reach" % net_id)
	var hp_max := maxf(1.0, float(c.get("hp_max", 1.0)))
	if float(c.get("hp", 0.0)) <= 0.0 or float(c.get("cooldown", 0.0)) > 0.0 or not bool(c.get("knocked", false)) or not FieldTame.health_allows_capture(float(c.hp) / hp_max):
		return no("not_ready", "%s must be knocked out and under %d%% health" % [net_id, int(FieldTame.CAPTURE_HEALTH_FRAC * 100.0)])
	var food_id := StringName(str(food))
	var value := FieldTame.PREFERRED_FEED if food_id in def.preferred_food else (FieldTame.ACCEPTED_FEED if food_id in def.accepted_food else 0.0)
	if value <= 0.0:
		return no("bad_request", "refused: needs %s" % (def.preferred_food[0] if not def.preferred_food.is_empty() else &"berry"))
	var inv := ch.inventory()
	var idx := inv.find_first(food_id)
	if idx < 0:
		return no("insufficient_items", "no %s in the bag" % food_id)
	inv.remove_at(idx, 1)
	var feeds := float(c.get("feeds", 0.0)) + value
	var r := {"feeds": feeds, "needed": def.feeds_needed}
	if def.requires_pen or feeds + 0.001 < def.feeds_needed:
		_write("set_tame_feeds", [net_id, feeds])
	else:
		# Wild genetics come from the island when it has rolled them, else from this op's RNG.
		var g: Variant = c.get("genetics")
		var genetics := CreatureGenetics.from_dict(g) if g is Dictionary and not (g as Dictionary).is_empty() else CreatureGenetics.roll(rng)
		var pet := PetRecord.from_def(def, genetics.overall_tier(), StringName(str(c.get("variant", ""))), genetics).to_dict()
		# W1-TAME's PetRecord stamps the wall clock and a blank owner; the op's ts and account keep replay exact.
		pet["tamed_at"] = now
		pet["owner"] = str(account)
		var uid := Provenance.pet_uid(seq, 0)
		ch.d.pets[uid] = Provenance.stamp(pet, uid, "tame", seq)
		s.pets_minted = int(s.pets_minted) + 1
		_write("bond_creature", [net_id, uid, account])
		r["pet_uid"] = uid
	ch.commit(inv, "tame", seq)
	count("consumed", food_id, 1)
	return ok(r)

## act.capture {net_id}: throw the best net (CaptureSystem.attempt's chance) at a knocked-out
## creature under 30 % health; success bags a captured_animal stack, failure wakes it.
# ASSUMPTION: capture-technique unlocks are still client-side (Data.survival_unlocked); the
# server checks net tier against species tier only until skill nodes move here (W3-SRVACT).
func _capture(ch: CharacterState, a: Dictionary) -> Dictionary:
	var net_id: Variant = text(a, "net_id")
	if net_id == null:
		return no("bad_request", "net_id is required")
	var c := _read("creature", [net_id])
	if c.is_empty():
		return no("not_found", "no creature %s" % net_id)
	var def := Data.creature(StringName(str(c.get("species", ""))))
	if def == null or not def.tameable or bool(c.get("pet", false)):
		return no("bad_request", "%s cannot be captured" % net_id)
	if ch.pos().distance_to(WorldFacade.v3(c.get("pos"))) > body_reach(def) + REACH_SLACK:
		return no("out_of_range", "%s is out of reach" % net_id)
	var frac := float(c.get("hp", 0.0)) / maxf(1.0, float(c.get("hp_max", 1.0)))
	if frac <= 0.0 or not bool(c.get("knocked", false)) or not FieldTame.health_allows_capture(frac):
		return no("not_ready", "%s must be knocked out and under %d%% health" % [net_id, int(FieldTame.CAPTURE_HEALTH_FRAC * 100.0)])
	var inv := ch.inventory()
	var net := inv.best_capture_net()
	if net == null or net.def().capture_tier < def.capture_tier:
		return no("missing_tool", "needs a tier %d capture net" % def.capture_tier)
	var net_id_def := net.def_id
	var chance := clampf(float(CaptureSystem.TIER_BASE.get(net.def().capture_tier, 0.35)) * (1.5 - frac), 0.05, 0.90)
	if rng.randf() >= chance:
		_write("fail_capture", [net_id]) # the client releases the knockdown and enrages it
		return ok({"captured": false, "chance": chance}) # commits: the throw spent this seq's roll
	var g: Variant = c.get("genetics")
	var genetics := CreatureGenetics.from_dict(g) if g is Dictionary and not (g as Dictionary).is_empty() else CreatureGenetics.roll(rng)
	var stack := ItemStack.make(&"captured_animal", 1, {"species": str(def.id), "variant": str(c.get("variant", "")), "grade_seed": rng.randi(), "genetics": genetics.to_dict()})
	if inv.add(stack) > 0:
		return no("bag_full", "a captured animal needs %d free slots in a row" % stack.slot_span())
	inv.consume(net_id_def, 1)
	var uids := ch.commit(inv, "tame", seq)
	_write("bond_creature", [net_id, uids[0] if not uids.is_empty() else "", account])
	count("consumed", net_id_def, 1)
	count("minted", &"captured_animal", 1)
	return ok({"captured": true, "chance": chance, "uids": uids})

## act.attack {net_id}: one melee swing, Hunt.land_hit's formula and data/combat_tuning.json
## numbers on the server RNG. The creature's `dodge` is its effective dodge (evasion included).
# shortcut: melee only, never "from behind", no attacker statuses (accuracy_mult) or target
# statuses (defense_mult); ranged shots, facing and statuses come with W3-SRVACT.
func _attack(ch: CharacterState, a: Dictionary) -> Dictionary:
	var net_id: Variant = text(a, "net_id")
	if net_id == null:
		return no("bad_request", "net_id is required")
	var c := _read("creature", [net_id])
	if c.is_empty() or float(c.get("hp", 0.0)) <= 0.0:
		return no("not_found", "no living creature %s" % net_id)
	if bool(c.get("pet", false)):
		return no("not_owner", "%s is someone's pet" % net_id)
	var def := Data.creature(StringName(str(c.get("species", ""))))
	if def == null:
		return no("not_found", "unknown species for %s" % net_id)
	if ch.pos().distance_to(WorldFacade.v3(c.get("pos"))) > body_reach(def) + REACH_SLACK:
		return no("out_of_range", "%s is out of reach" % net_id)
	var inv := ch.inventory()
	var wi := ch.find_uid(str(ch.d.equipment.get("weapon", "")))
	var w := inv.slots[wi] if wi >= 0 else inv.equipped_weapon() # by uid: two clubs may differ in level
	var wd := w.def() if w else null
	if wd and wd.range_m > 0.0:
		return no("bad_request", "ranged attacks are not server-side yet")
	var tune := CombatTuning.section("player_melee")
	var dmg := w.scaled_damage() if w else float(tune.get("unarmed_damage", 8.0))
	var dtype := wd.damage_type if wd else &"blunt"
	if wd and wd.is_work_tool:
		dmg *= float(tune.get("work_tool_mult", 0.45))
	if rng.randf() >= CombatTuning.hit_chance(float(tune.get("base_accuracy", 1.0)), float(c.get("dodge", 0.0))):
		return ok({"dealt": 0.0, "kind": "dodge"}) # commits: the swing spent this seq's rolls
	var dealt := maxf(dmg * float(tune.get("min_damage_frac", 0.05)), dmg - float(c.get("defense", 0.0)) * float(tune.get("defense_factor", 0.5)))
	var melee := maxi(0, ch.level_of("melee") - SkillState.MIN_LEVEL) # bonuses count from Lv. 1
	dealt *= 1.0 + float(tune.get("damage_per_melee_level", 0.01)) * float(melee)
	dealt *= CombatCounters.multiplier(def.archetype, dtype)
	var kind := "hit"
	if rng.randf() < float(tune.get("crit_base", 0.08)) + float(tune.get("crit_per_melee_level", 0.002)) * float(melee):
		dealt *= float(tune.get("crit_mult", 1.75))
		kind = "crit"
	_write("damage_creature", [net_id, dealt])
	ch.add_xp("melee", int(tune.get("xp_per_hit", 2)))
	return ok({"dealt": dealt, "kind": kind, "hp": maxf(0.0, float(c.hp) - dealt)})

## act.deposit {bag_slot, count?} | {pet_uid}: hands a server-provenance asset to the economy
## (the caller puts it in the vault). Any asset dict in the request is refused.
func _deposit(ch: CharacterState, a: Dictionary) -> Dictionary:
	for k in ASSET_DICT_KEYS:
		if a.has(k):
			return no("invalid_asset", "deposits take a bag slot or a pet uid of the server character")
	if a.has("pet_uid"):
		var uid: Variant = text(a, "pet_uid")
		if uid == null:
			return no("bad_request", "pet_uid must be a 1..64 character string")
		if not ch.d.pets.has(uid):
			return no("not_found", "no pet %s" % uid)
		var pet: Dictionary = ch.d.pets[uid]
		if not Provenance.is_server(pet):
			return no("invalid_asset", "pet %s has no server provenance" % uid)
		ch.d.pets.erase(uid)
		s.pets_exported = int(s.pets_exported) + 1
		_export(pet)
		return ok({"kind": "pet", "asset": pet})
	var i: Variant = integer(a, "bag_slot", 0, (ch.d.bag as Array).size() - 1)
	var n: Variant = integer(a, "count", 1, 1000000, 1000000)
	if i == null or n == null:
		return no("bad_request", "bag_slot (and an optional count >= 1) or pet_uid is required")
	var row: Variant = ch.d.bag[int(i)]
	if not row is Dictionary or str(row.get("id", "")) == str(CharacterState.LOCK):
		return no("not_found", "bag slot %d is empty" % i)
	if not Provenance.is_server(row):
		return no("invalid_asset", "bag slot %d has no server provenance" % i)
	var inv := ch.inventory()
	var taken := inv.remove_at(int(i), mini(int(n), int(row.count)))
	var asset := taken.to_dict()
	if taken.count >= int(row.count):
		asset = (row as Dictionary).duplicate(true) # the instance itself: every field it carries leaves with it
	else:
		Provenance.stamp(asset, Provenance.item_uid(seq, 0), str(row.origin), seq) # a part gets a new uid
	ch.commit(inv, str(row.origin), seq)
	count("exported", taken.def_id, taken.count)
	_export(asset)
	return ok({"kind": "item", "asset": asset})

## Records the exact body that left, so char.receive takes back only that asset, only once.
func _export(asset: Dictionary) -> void:
	s.exported_assets[str(asset.uid)] = CharacterStore.canon(CharacterStore.wire(asset))

# --- system ops --------------------------------------------------------------------------

## char.move {p: [x, y, z], reset?}: the presence layer commits an accepted position; reach
## checks use it. Contract §7's bound (1.6 x run speed per second) applies unless `reset` (travel).
func _move(ch: CharacterState, a: Dictionary) -> Dictionary:
	var p: Variant = a.get("p")
	if not (p is Array and (p as Array).size() == 3):
		return no("bad_request", "p must be [x, y, z]")
	for v in p:
		if not (v is int or v is float) or not is_finite(float(v)) or absf(float(v)) > 100000.0:
			return no("bad_request", "p must be three finite numbers")
	var to := WorldFacade.v3(p)
	var step := ch.pos().distance_to(to)
	# A budget, not a per-update cap: updates in the same second share one second's distance,
	# so 10 Hz presence (contract §7) cannot multiply the bound. ts is whole seconds.
	var elapsed := mini(now - int(ch.d.pos_ts), 2) # a long silence banks at most 2 s of distance
	var used := 0.0 if elapsed > 0 else float(ch.d.get("move_cm", 0)) / 100.0
	var limit := 1.6 * RUN_SPEED * float(maxi(1, elapsed)) + 1.0 - used
	var reset: Variant = a.get("reset", false)
	if not reset is bool:
		return no("bad_request", "reset must be true or false")
	if not reset and step > limit:
		return no("bad_request", "moved %.1f m, more than the %.1f m left this second" % [step, maxf(0.0, limit)])
	ch.d.pos = p
	ch.d.pos_ts = now
	ch.d.move_cm = 0 if reset else ceili((used + step) * 100.0) # whole cm: a float sum would not survive the JSON snapshot bit-exact
	return ok({"p": p})

## char.wallet {wallet}: mirrors the economy wallet (the ledger stays the authority).
func _wallet(ch: CharacterState, a: Dictionary) -> Dictionary:
	var w: Variant = integer(a, "wallet", 0, 9007199254740991)
	if w == null:
		return no("bad_request", "wallet must be a non-negative integer")
	if int(ch.d.wallet) == int(w):
		return ok({"wallet": w}, false)
	ch.d.wallet = w
	return ok({"wallet": w})

## char.receive {asset}: the economy hands back an asset act.deposit exported (a vault that
## refused it, or a withdrawal). Only the exact body act.deposit recorded under that uid comes
## back, once. Economy-minted assets (market, settlers, objective) have no entry: see the report.
## An item that lands as its own row is the exported body again, uid and seq included (W2-INV:
## every material is an instance); units that merge into a stack take that stack's, as everywhere.
func _receive(ch: CharacterState, a: Dictionary) -> Dictionary:
	var asset: Variant = a.get("asset")
	if not Provenance.is_server(asset):
		return no("invalid_asset", "only assets with server provenance come back")
	var uid := str(asset.uid)
	if uid.begins_with("p"):
		for key: String in s.chars:
			if (s.chars[key].pets as Dictionary).has(uid):
				return no("conflict", "pet %s is already held" % uid)
	if str(s.exported_assets.get(uid, "")) != CharacterStore.canon(asset):
		return no("invalid_asset", "%s is not an asset this server exported (or it was edited)" % uid)
	if uid.begins_with("p"): # the roster cap is VaultBridge's: a refused deposit coming back is no new bond
		s.exported_assets.erase(uid)
		ch.d.pets[uid] = (asset as Dictionary).duplicate(true)
		ch.d.pets[uid].owner = str(account) # a bought pet answers to its new owner; tamer keeps the lineage
		s.pets_exported = int(s.pets_exported) - 1
		return ok({"kind": "pet", "pet_uid": uid})
	var stack := ItemStack.from_dict(Provenance.strip(asset))
	if stack.def() == null or stack.count < 1:
		return no("invalid_asset", "%s is not a valid stack" % uid)
	var n := stack.count
	var inv := ch.inventory()
	if inv.add(stack) > 0:
		return no("bag_full", "no room for %s" % stack.def_id)
	s.exported_assets.erase(uid)
	var uids := ch.commit(inv, str(asset.origin), seq)
	var row := ch.find_uid(uids[0]) if uids.size() == 1 else -1
	if row >= 0 and int(ch.d.bag[row].count) == n: # landed as its own row: the same instance comes home
		ch.d.bag[row] = (asset as Dictionary).duplicate(true) # the exact body act.deposit recorded
		uids = [uid]
	count("exported", stack.def_id, -n)
	return ok({"kind": "item", "item": str(stack.def_id), "count": n, "uids": uids})

## char.grant {asset}: units the economy split off an export (a partial buy, a part listing,
## an order fill, the seller's remainder, part of a stack) come home. Server-only: VaultBridge
## calls it after the vault let go of those units, so they count as exported units coming back,
## like char.receive, and never more than are out: the grant cannot mint.
func _grant(ch: CharacterState, a: Dictionary) -> Dictionary:
	var asset: Variant = a.get("asset")
	if not asset is Dictionary or str((asset as Dictionary).get("uid", "")).begins_with("p"):
		return no("bad_request", "asset must be an item stack")
	var stack := ItemStack.from_dict(Provenance.strip(asset))
	if stack.def() == null or stack.count < 1 or stack.count > stack.def().stack_max:
		return no("invalid_asset", "not a valid stack")
	var n := stack.count
	if int(s.exported.get(str(stack.def_id), 0)) < n:
		return no("invalid_asset", "only %d %s are out in the economy" % [int(s.exported.get(str(stack.def_id), 0)), stack.def_id])
	var inv := ch.inventory()
	if inv.add(stack) > 0:
		return no("bag_full", "no room for %s" % stack.def_id)
	var origin := str(asset.get("origin", ""))
	var uids := ch.commit(inv, origin if origin in Provenance.ORIGINS else "market", seq)
	var row := ch.find_uid(uids[0]) if uids.size() == 1 else -1
	if row >= 0 and int(ch.d.bag[row].count) == n: # its own row: the part keeps who made it and when
		for k: String in ["creator", "created_at"]:
			if (asset as Dictionary).has(k):
				ch.d.bag[row][k] = asset[k]
	count("exported", stack.def_id, -n)
	return ok({"item": str(stack.def_id), "count": n, "uids": uids})

## char.settled {uid}: the vault bridge reports that the economy kept an exported asset for
## good (sold, consumed). It can never come back, so its exported_assets record is dropped and
## the registry holds only assets in flight.
func _settled(a: Dictionary) -> Dictionary:
	var uid: Variant = text(a, "uid")
	if uid == null:
		return no("bad_request", "uid is required")
	if not s.exported_assets.has(uid):
		return no("not_found", "%s is not an exported asset in flight" % uid)
	s.exported_assets.erase(uid)
	return ok({"uid": uid})

# --- helpers -----------------------------------------------------------------------------

## The op's args with every key it does not read dropped (see ARG_KEYS).
static func known_args(op: String, a: Dictionary) -> Dictionary:
	var out := {}
	for k: String in (ARG_KEYS.get(op, []) as Array) + ["rid"]:
		if a.has(k):
			out[k] = a[k]
	return out

## Hunt.melee_reach on a def: the edge of large bodies, at least 2.1 m.
static func body_reach(def: CreatureDef) -> float:
	return maxf(2.1, maxf(0.18, def.real_length_m * 0.12) + 0.65)

## Live: asks the world and records the answer (as the journal will store it). Replay: hands
## back the recorded answer and never touches the world.
func _read(method: String, args: Array) -> Dictionary:
	if replaying:
		var got: Variant = tape[_tape_i] if _tape_i < tape.size() else {}
		_tape_i += 1
		return got if got is Dictionary else {}
	var d: Variant = CharacterStore.wire(world.callv(method, args))
	tape.append(d if d is Dictionary else {})
	return tape[-1]

## Queued, not applied: an op that fails or errors after this line leaves the island untouched.
func _write(method: String, args: Array) -> void:
	if not replaying:
		writes.append([method, args])

func flush() -> void:
	for w: Array in writes:
		world.callv(w[0], w[1])
	writes.clear()

func count(counter: String, def_id: StringName, n: int) -> void:
	var d: Dictionary = s[counter]
	d[str(def_id)] = int(d.get(str(def_id), 0)) + n

static func text(a: Dictionary, key: String, max_len: int = 64) -> Variant:
	var v: Variant = a.get(key)
	return str(v) if v is String and (v as String).length() >= 1 and (v as String).length() <= max_len else null

## An int in lo..hi, `fallback` when the key is absent, null when present but invalid.
static func integer(a: Dictionary, key: String, lo: int, hi: int, fallback: Variant = null) -> Variant:
	if not a.has(key) or a[key] == null:
		return fallback
	var v: Variant = a[key]
	return int(v) if v is int and int(v) >= lo and int(v) <= hi else null

## `changed = false` marks a success that touched nothing (no seq, no journal line).
static func ok(r: Dictionary, changed: bool = true) -> Dictionary:
	return {"ok": true, "r": r} if changed else {"ok": true, "r": r, "noop": true}

static func no(code: String, msg: String) -> Dictionary:
	return {"ok": false, "err": code, "msg": msg}
