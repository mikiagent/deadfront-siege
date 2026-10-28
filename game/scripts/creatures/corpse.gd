class_name Corpse
extends StaticBody3D
## Loot marker + timed corpse lifecycle. The dead creature mesh stays in its death pose.

var species: StringName = &""
var level: int = 1
var source_pack: int = 0
var loot: Inventory = Inventory.new(12)
var _expires_left: float = 90.0 # ASSUMPTION: corpse lifetime on the ground.
var _empty_despawn: float = 20.0 # ASSUMPTION: looted-empty corpses fade sooner.
var _owner: Creature
var _marker: Node3D
var _label_species: String = ""
var _tap_s: float = -999.0
var _fading: bool = false
var _emptied: bool = false
var poison_spoiled: bool = false
## Loot units per drop kind at the last take, and the kinds Butchering XP was paid for: 3 XP per
## kind, the first time any of it leaves the loot. A take only pays when units really moved (a full
## bag used to pay +3 XP per tap with nothing taken); with one instance per unit (W2-INV) a take
## of each item must not pay per unit, so item takes and Take all pay the same.
var _units_seen: Dictionary = {}
var _paid_kinds: Dictionary = {}
## BUTCHER (spec 12 §2): the survivor cuts the parts they choose, one cut each, out of a budget of
## 1 + floor(Butchering level / 10) (CarcassParts.CUTS_BASE / LEVELS_PER_CUT). Parts never cut are
## lost when the carcass despawns.
var cuts_budget: int = 1
var cuts_left: int = 1
var cut_parts: Array[StringName] = []

func setup(c: Creature) -> void:
	level = maxi(1, int(c.get("level")) if c.get("level") != null else 1)
	species = c.def.id
	source_pack = c.pack_id
	_owner = c
	_label_species = c.def.species
	name = "Corpse_%s" % species
	poison_spoiled = c.statuses.has_flag(&"meat_inedible")
	_roll_loot()
	_snap_owner_to_ground()
	# BUTCHER (spec 12 §2): the cut budget is the killer's, fixed at death like the loot roll.
	var p := PlayerRegistry.local()
	cuts_budget = CarcassParts.cut_budget(maxi(0, p.skills.level_of("butchering")) if p != null and p.skills != null else 0)
	cuts_left = cuts_budget

func _ready() -> void:
	add_to_group("corpse")
	collision_layer = 1
	collision_mask = 0
	_marker = _build_marker()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.55
	sh.height = 0.8
	cs.shape = sh
	cs.position.y = 0.4
	add_child(cs)
	_place_on_tile()
	_units_seen = _kind_units()
	if _owner:
		_owner.visible = true
		_owner.collision_layer = 0
		_owner.collision_mask = 1
		# The body keeps its terrain collision but must not stand on its own loot cylinder
		# (it floated 0.9 m on it).
		_owner.add_collision_exception_with(self)

func can_butcher(inv: Inventory) -> String:
	if _is_empty():
		return "empty"
	if not inv.has_tool_class(&"knife"):
		return "need tool knife"
	return ""

func butcher(player: Player) -> Array[ItemStack]:
	open_loot(player)
	return []

func open_loot(player: Player) -> void:
	if player == null or player.ui == null:
		return
	note_tapped()
	if _is_empty():
		_on_loot_empty()
		if player.has_method("notice"):
			player.notice("Nothing left on the %s." % species_display_name().to_lower())
		return
	_units_seen = _kind_units()
	var why := can_butcher(player.inventory)
	var readonly := "needs knife" if why == "need tool knife" else ""
	player.ui.show_storage(loot, player, {
		"title": "Loot · %s" % species_display_name(),
		"take_all": true,
		"readonly_reason": readonly,
		"on_take": Callable(self, "_on_take_from_loot"),
		"on_empty": Callable(self, "_on_loot_empty"),
	})
	if readonly == "":
		player.inventory.wear_gather_tool(&"knife")

## Radial options (Durango reference): one hex per loot stack, 1.6 s each, knife-gated.
func loot_options(inv: Inventory) -> Array:
	var out: Array = []
	var needs_knife := not inv.has_tool_class(&"knife")
	for i in loot.slot_count:
		var st: ItemStack = loot.slots[i]
		if st == null:
			continue
		out.append({"item": str(st.def_id), "min": st.count, "max": st.count, "tool": "knife" if needs_knife else "none", "seconds": 1.6, "slot": i})
	return out

# ---------------------------------------------------------------- BUTCHER: part cuts (spec 12 §2)

## The carcass's part list for the picker: one entry per data part (CarcassParts.parts), with the
## units the cut would give, whether it is already off the carcass, and why it cannot be cut now.
## Each cut spends one of `cuts_left`; a part never cut stays on the carcass and is lost on despawn.
func part_options(p: Player) -> Array:
	var out: Array = []
	if p == null:
		return out
	var ctx := cut_context(p)
	for part in CarcassParts.parts(species):
		var id: StringName = part["id"]
		var count := loot.count_of(id)
		var row: Dictionary = part["row"]
		var entry := {
			"id": id,
			"name": Data.item(id).display_name if Data.item(id) != null else str(id),
			"min": int(row.get("min", 1)),
			"max": int(row.get("max", 1)),
			"count": count,
			"cut": cut_parts.has(id),
			"rare": not (part.get("rare", {}) as Dictionary).is_empty(),
			"seconds": CarcassParts.CUT_SECONDS,
			"blocked": "",
		}
		if cut_parts.has(id):
			entry["blocked"] = "cut"
		elif count <= 0:
			entry["blocked"] = "nothing left"
		else:
			entry["blocked"] = CarcassParts.reason(part, ctx)
		out.append(entry)
	return out

## The knife tier / Butchering level / node gates this carcass's cuts are judged by.
func cut_context(p: Player) -> Dictionary:
	return CarcassParts.context(p, level, poison_spoiled, cuts_left, cut_parts)

## Cut one chosen part off the carcass: only that part's stacks leave (`only it`), one cut of the
## budget is spent, and the knife wears. Nothing to give / no cuts left / already cut -> [].
## The caller is the timed action (PlayerActions.finish_part_cut), so a cancelled cut never reaches
## here and spends nothing.
func cut_part(id: StringName, p: Player) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	if p == null or cuts_left <= 0 or cut_parts.has(id):
		return out
	var part := _part_of(id)
	if part.is_empty():
		return out
	if CarcassParts.reason(part, cut_context(p)) != "":
		return out
	for i in loot.slot_count:
		var st: ItemStack = loot.slots[i]
		if st == null or st.def_id != id:
			continue
		var taken := loot.remove_at(i, st.count)
		if taken != null:
			out.append(taken)
	cut_parts.append(id)
	cuts_left = maxi(0, cuts_left - 1)
	note_tapped()
	p.inventory.wear_gather_tool(&"knife")
	if _is_empty():
		_on_loot_empty()
	return out

## The data part entry for one item id ({} when the species has none).
func _part_of(id: StringName) -> Dictionary:
	for part in CarcassParts.parts(species):
		if part["id"] == id:
			return part
	return {}

## Save/load: the budget and the parts already cut come back with the carcass.
func apply_cut_state(budget: int, left: int, parts: Array) -> void:
	cuts_budget = maxi(1, budget)
	cuts_left = clampi(left, 0, cuts_budget)
	cut_parts.clear()
	for id in parts:
		var s := StringName(str(id))
		if s != &"" and not cut_parts.has(s):
			cut_parts.append(s)

func has_cuts_left() -> bool:
	return cuts_left > 0 and not _is_empty()

## Take one loot stack (after the 1.6 s butcher). Returns the stack or null.
func take_slot(slot: int, player: Player) -> ItemStack:
	if slot < 0 or slot >= loot.slot_count or loot.slots[slot] == null:
		return null
	var st: ItemStack = loot.slots[slot]
	var taken := loot.remove_at(slot, st.count)
	if taken and player:
		player.inventory.wear_gather_tool(&"knife")
	_on_take_from_loot()
	return taken

func species_display_name() -> String:
	return _label_species if _label_species != "" else str(species).capitalize()

func plate_anchor() -> Vector3:
	return global_position + Vector3(0.0, 1.05, 0.0)

func note_tapped() -> void:
	_tap_s = _now_s()

func tapped_recently(seconds: float) -> bool:
	return _now_s() - _tap_s <= seconds

func _process(delta: float) -> void:
	if _fading:
		return
	_expires_left = maxf(0.0, _expires_left - delta)
	if _expires_left <= 0.0:
		_begin_fade()
		return
	if _is_empty() and not _emptied:
		_emptied = true
		_expires_left = minf(_expires_left, _empty_despawn)

func _roll_loot() -> void:
	# W2-GATHER: knife tier + Butchering level scale the parts, rare rows roll real odds; the
	# Butchering skill-node gate (Data.butcher_row_open) still applies inside LootRoller.
	ButcherLoot.roll_into(self, _owner)

func _on_take_from_loot() -> void:
	# Taking from the chest screen trains Butchering (and so the player level), once per take
	# that actually moved units out of the loot.
	var now := _kind_units()
	var p := PlayerRegistry.local()
	for k: StringName in _units_seen:
		if p and p.skills and int(now.get(k, 0)) < int(_units_seen[k]) and first_take_of(k):
			p.skills.add_xp("butchering", 3)
	_units_seen = now
	if _is_empty():
		_on_loot_empty()

func _on_loot_empty() -> void:
	if not _emptied:
		_emptied = true
		_expires_left = minf(_expires_left, _empty_despawn)

func _is_empty() -> bool:
	return loot.used_slots() <= 0

## True once per drop kind: the take that pays its Butchering XP (radial loot and the chest screen).
func first_take_of(def_id: StringName) -> bool:
	if _paid_kinds.has(def_id):
		return false
	_paid_kinds[def_id] = true
	return true

func _kind_units() -> Dictionary:
	var n := {}
	for st in loot.slots:
		if st:
			n[st.def_id] = int(n.get(st.def_id, 0)) + st.count
	return n

## Dropped loot on the floor: a billboard loot-bag symbol with the top item's icon over it,
## bobbing gently (tap it to open the chest screen). Falls back to the Kenney box.
func _build_marker() -> Node3D:
	var marker := Node3D.new()
	marker.name = "LootMarker"
	add_child(marker)
	var bag_tex := ItemIcons.texture(&"loot_bag")
	if bag_tex:
		var bag := Sprite3D.new()
		bag.texture = bag_tex
		bag.pixel_size = 0.0042
		bag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bag.shaded = false
		bag.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		bag.position = Vector3(0, 0.42, 0)
		marker.add_child(bag)
		var top: ItemStack = null
		for i in loot.slot_count:
			if loot.slots[i]:
				top = loot.slots[i]
				break
		if top:
			var item := Sprite3D.new()
			item.texture = ItemIcons.texture(top.def_id)
			if item.texture:
				item.pixel_size = 0.0026
				item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				item.shaded = false
				item.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
				item.position = Vector3(0.22, 0.78, 0)
				marker.add_child(item)
		var tw := create_tween().set_loops()
		tw.tween_property(marker, "position:y", 0.14, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(marker, "position:y", 0.02, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return marker
	var path := "res://assets/props/kenney/box-open.glb"
	var placed := false
	if ResourceLoader.exists(path):
		var packed := load(path)
		if packed is PackedScene:
			marker.add_child((packed as PackedScene).instantiate())
			placed = true
	if not placed:
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.22
		cyl.bottom_radius = 0.22
		cyl.height = 0.03
		disc.mesh = cyl
		disc.position.y = 0.02
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.86, 0.84, 0.72, 0.9)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc.material_override = mat
		marker.add_child(disc)
		return marker
	marker.scale = Vector3.ONE * 0.35
	return marker

func _place_on_tile() -> void:
	if World.runtime == null:
		return
	var tile := BuildGrid.tile_of(global_position)
	global_position = BuildGrid.tile_centre(tile, World.runtime)
	if _marker:
		_marker.position = Vector3(0.0, 0.08, 0.0)

func _snap_owner_to_ground() -> void:
	if _owner == null or World.runtime == null:
		return
	var tile := BuildGrid.tile_of(_owner.global_position)
	var ground := BuildGrid.tile_centre(tile, World.runtime)
	_owner.global_position = ground + Vector3(0.0, 0.1, 0.0)

func _begin_fade() -> void:
	if _fading:
		return
	_fading = true
	collision_layer = 0
	collision_mask = 0
	print("[world] corpse despawned %s" % species)
	var tw := create_tween()
	# Shrink to a sliver, not exactly zero: a CharacterBody3D with a zero scale has a singular basis and
	# logged an engine error every physics frame for the last half second of the fade.
	var sliver := Vector3.ONE * 0.001
	if _marker:
		tw.parallel().tween_property(_marker, "scale", sliver, 0.45)
	if _owner and is_instance_valid(_owner):
		tw.parallel().tween_property(_owner, "scale", sliver, 0.55)
	tw.tween_interval(0.56)
	if _owner and is_instance_valid(_owner):
		tw.tween_callback(_owner.queue_free)
	tw.tween_callback(queue_free)

func _now_s() -> float:
	return float(Time.get_ticks_msec()) * 0.001
