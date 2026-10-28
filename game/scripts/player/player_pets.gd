class_name PlayerPets
extends RefCounted
## The survivor's bonded animals: summon and dismiss (HP kept), the pet radial (Animals, Bag, Feed,
## Ride, Dismiss, Rename; spec 23), whistle orders, feeding, bag dumps that never delete, and riding.

## Up to MAX_OUT pets at once.
const MAX_OUT := 3
## Pet radial segments, clockwise from the top left as in the reference. icon = UiIcons id (white
## action symbols). Orders are not here: the whistle hexes (SIC / HEEL / GUARD) stay on the HUD.
const MENU := {
	&"animals": {"id": &"animals", "label": "Animals", "icon": "animals"},
	&"bag": {"id": &"bag", "label": "Bag", "icon": "bag"},
	&"feed": {"id": &"feed", "label": "Feed", "icon": "feed"},
	&"ride": {"id": &"ride", "label": "Ride", "icon": "ride"},
	&"dismount": {"id": &"dismount", "label": "Dismount", "icon": "dismount"},
	&"dismiss": {"id": &"dismiss", "label": "Dismiss", "icon": "dismiss"},
	&"rename": {"id": &"rename", "label": "Rename", "icon": "rename"},
}
## HP a pet out of the bag has now, kept on its record so a dismissed pet comes back hurt and a save
## keeps it. Uses PetRecord.hp_now once that field exists (integrator hook, saved with the record).
# shortcut: until then it is record metadata, kept through dismiss/summon but not through save/load.
const HP_KEY := &"hp_now"

var p: Player
var summoned: Array[Creature] = []
## The pet the menu was last opened on: Feed and the bag screen's feed button act on it.
var focus: Creature
var menu: PetRadial
var rename_dialog: PetRenameDialog
var mount_hips_offset := Vector3.ZERO
var _mount_saved_parent: Node
var _rig_rest: Transform3D

func _init(player: Player) -> void:
	p = player

func prune() -> void:
	for i in range(summoned.size() - 1, -1, -1):
		var c := summoned[i]
		if c == null or not is_instance_valid(c) or c.health.dead:
			if c and is_instance_valid(c) and c.pet_record:
				c.pet_record.summoned = false
				_store_hp(c.pet_record, -1.0)  # a pet that died comes back at full health
			summoned.remove_at(i)
		elif c.pet_record:
			_store_hp(c.pet_record, c.health.hp)

## -1 = nothing stored (full health).
static func stored_hp(rec: PetRecord) -> float:
	return float(rec.get(HP_KEY) if HP_KEY in rec else rec.get_meta(HP_KEY, -1.0))

static func _store_hp(rec: PetRecord, hp: float) -> void:
	if HP_KEY in rec:
		rec.set(HP_KEY, hp)
	else:
		rec.set_meta(HP_KEY, hp)

func live() -> Array[Creature]:
	prune()
	return summoned

func nearest(max_d: float) -> Creature:
	var best: Creature = null
	var best_d := max_d
	for c in live():
		var d := p.global_position.distance_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best

func _out_for(rec: PetRecord) -> Creature:
	for c in live():
		if c.pet_record == rec:
			return c
	return null

func bond_from_inventory() -> void:
	var idx := p.inventory.find_first(&"tamed_animal")
	if idx < 0:
		return
	if p.bonded.size() >= Data.bonded_cap():
		print("[capture] bonded cap %d" % Data.bonded_cap())
		return
	var stack := p.inventory.remove_at(idx, 1)
	var species := StringName(str(stack.attributes.get("species", "velociraptor")))
	var def := Data.creature(species)
	var grade := StringName(str(stack.attributes.get("grade", "B")))
	var rec := PetRecord.from_def(def, grade, StringName(str(stack.attributes.get("variant", ""))), CreatureGenetics.from_dict(stack.attributes.get("genetics", {})))
	p.bonded.append(rec)
	print("[capture] bonded %s grade=%s hp=%.0f atk=%.0f def=%.0f spd=%.0f" % [
		species, grade, rec.hp, rec.attack, rec.defense, rec.speed])

## Toggle one bonded record: dismiss it if it is out, else summon it (up to MAX_OUT out).
func summon(index: int = 0) -> Creature:
	if p.bonded.is_empty():
		return null
	var rec := p.bonded[clampi(index, 0, p.bonded.size() - 1)]
	var out := _out_for(rec)
	if out:
		dismiss(out)
		return null
	if rec.respawning():
		p.notice("%s is down - back in %ds." % [str(rec.species).capitalize(), int(ceil(rec.respawn_left))])
		return null
	if live().size() >= MAX_OUT:
		p.notice("Only %d pets can be out at once." % MAX_OUT)
		return null
	var def := Data.creature(rec.species)
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	# Placed before it enters the tree: a body added at the parent's origin is simulated there for
	# a step and gets launched out of whatever it overlaps (phys-spawn-01, ~90 m/s).
	var host := p.get_parent()
	var at := p.global_position + Vector3(1.5 + 1.2 * float(summoned.size()), 0, 0)
	var rt := World.runtime
	at.y = rt.surface_y(at.x, at.z) if rt and rt.has_method("surface_y") else p.feet_position().y
	c.position = host.to_local(at) if host is Node3D else at
	c.is_pet = true
	c.pet_record = rec
	c.genetics = rec.genetics
	host.add_child(c)
	c.spawn(def, rec.variant)
	c.velocity = Vector3.ZERO
	c.hunger = rec.hunger
	c.hunger_max = rec.hunger_max
	c.health.max_hp = rec.hp
	# A pet dismissed hurt comes back hurt (tame-11); nothing stored = full health.
	var kept := stored_hp(rec)
	c.health.hp = clampf(kept, 1.0, rec.hp) if kept >= 0.0 else rec.hp
	c.level = rec.level
	summoned.append(c)
	rec.summoned = true
	print("[capture] summoned %s hp=%.0f/%.0f (wild hp=%.0f)" % [def.id, c.health.hp, c.health.max_hp, def.hp])
	return c

func dismiss(c: Creature) -> void:
	var rec := c.pet_record
	summoned.erase(c)
	if p.mounted_on == c:
		p.dismount()
	if rec:
		_store_hp(rec, c.health.hp)
		rec.summoned = false
		print("[capture] dismissed %s hp=%.0f/%.0f" % [rec.species, c.health.hp, c.health.max_hp])
	if focus == c:
		focus = null
	c.queue_free()

## Whistle: "attack" sics the pets on the current target, "heel" calls them back, "guard" is the default.
func order(cmd: StringName) -> void:
	var pets := live()
	if pets.is_empty():
		p.notice("No pet out. Summon one from PETS.")
		return
	var t: Creature = p.hunt.target if (p.hunt and p.hunt.target and is_instance_valid(p.hunt.target)) else null
	if cmd == &"attack" and t == null:
		t = p.controls.selection.shown()  # SIC with no fight: the selected animal (PRD 10.2 "pets join")
	if cmd == &"attack" and t == null:
		t = p.actions.nearest_creature(30.0, false)  # else the nearest wild animal
		if t == null:
			p.notice("No enemy nearby to sic them on.")
			return
	for pet in pets:
		if pet.brain and pet.brain.has_method("order"):
			pet.brain.order(cmd, t)
	var who := "Your pet" if pets.size() == 1 else "Your %d pets" % pets.size()
	match cmd:
		&"attack":
			p.notice("%s: attack %s!" % [who, str(t.def.species)])
		&"heel":
			p.notice("%s heel." % who)
		_:
			p.notice("%s guard you." % who)

# ---------------------------------------------------------------- pet radial

func setup_menu(layer: CanvasLayer) -> void:
	menu = PetRadial.new()
	menu.name = "PetRadial"
	menu.player = p
	layer.add_child(menu)
	menu.action_chosen.connect(_on_menu)
	rename_dialog = PetRenameDialog.new()
	rename_dialog.name = "PetRename"
	layer.add_child(rename_dialog)

## Tap (or interact key) on your own pet: its radial; the same pet again closes it.
func interact(c: Creature) -> void:
	if c == null or c.pet_record == null:
		return
	focus = c
	if menu == null:
		if &"mount" in c.pet_record.tamed_role:
			p.mount(c)
		elif p.ui:
			p.ui.show_pet_bag(c.pet_record)
		return
	if menu.visible and menu.pet == c:
		menu.hide_menu()
		return
	menu.show_for(c, entries(c))

## What this pet can do now; anything it cannot is left out. Animals needs the HUD's Animals screen,
## Bag a bag (tame-13), Ride a mount species (Dismount while you ride it).
func entries(c: Creature) -> Array:
	var out: Array = []
	var hud := p.get_tree().get_first_node_in_group("hud") if p.is_inside_tree() else null
	if hud and hud.has_method("open_animals"):
		out.append(MENU[&"animals"])
	if c.pet_record.bag:
		out.append(MENU[&"bag"])
	out.append(MENU[&"feed"])
	if &"mount" in c.pet_record.tamed_role:
		out.append(MENU[&"dismount"] if p.mounted_on == c else MENU[&"ride"])
	out.append(MENU[&"dismiss"])
	if rename_dialog:
		out.append(MENU[&"rename"])
	return out

func _on_menu(anchor: Node3D, action_id: StringName) -> void:
	var c := anchor as Creature
	if c == null or not is_instance_valid(c) or c.health.dead:
		return
	focus = c
	match action_id:
		&"animals":
			var hud := p.get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("open_animals"):
				hud.open_animals(c.pet_record)
		&"bag":
			if p.ui:
				p.ui.show_pet_bag(c.pet_record)
		&"feed":
			feed_best(c)
		&"ride":
			if p.mounted_on and p.mounted_on != c:
				p.dismount()
			if p.mounted_on == null:
				p.mount(c)
		&"dismount":
			p.dismount()
		&"dismiss":
			dismiss(c)
		&"rename":
			var rec := c.pet_record
			rename_dialog.open(rec.name, func (nm: String) -> String: return p.actions.rename_pet(rec, nm))

## Feed one unit of the first food in the bag this pet eats.
func feed_best(c: Creature) -> bool:
	for i in p.inventory.slot_count:
		var s := p.inventory.slots[i]
		if s and Food._pet_accepts(c, s):
			return Food.feed_pet(p, c, s)
	p.notice("Nothing in your bag that a %s eats." % str(c.def.species).to_lower())
	return false

## The bag screen's feed button: the pet whose menu was opened last, else the nearest one out
## that eats it (tame-16: only the first summoned pet could be fed).
func feed_slot(index: int) -> bool:
	if index < 0 or index >= p.inventory.slot_count:
		return false
	var stack := p.inventory.slots[index]
	var pets := live()
	if focus and pets.has(focus) and (stack == null or Food._pet_accepts(focus, stack)):
		return Food.feed_pet(p, focus, stack)
	var best: Creature = null
	var best_d := INF
	for c in pets:
		var d := p.global_position.distance_to(c.global_position)
		if d < best_d and (stack == null or Food._pet_accepts(c, stack)):
			best_d = d
			best = c
	if best == null:
		print("[food] no summoned pet")
		return false
	return Food.feed_pet(p, best, stack)

## Empty a pet's bag into storage. Only what fits moves; the rest stays in the pet's bag
## (build-storage-01: overflow used to be deleted).
func dump_bag_into(c: Creature, dest: Inventory) -> int:
	var bag := c.pet_record.bag
	var moved := 0
	for i in bag.slot_count:
		if bag.slots[i] != null:
			moved += bag.transfer_to(dest, i)
	print("[item] pet dumped %d into basket%s" % [moved, "" if bag.used_slots() == 0 else " (rest kept: storage full)"])
	return moved

# ---------------------------------------------------------------- riding

func mount(c: Creature) -> void:
	if c.pet_record == null or not (&"mount" in c.pet_record.tamed_role):
		return
	p.mounted_on = c
	c.ridden = true
	_mount_saved_parent = p.get_parent()
	c.add_collision_exception_with(p)
	p.add_collision_exception_with(c)
	var rig := p.rig
	if rig and c.view.begin_ride():
		# The body rides the mount's root; only the rig follows the saddle bone (keeps physics off the bone).
		p._saddle_view = c.view
		_rig_rest = rig.transform
		p.reparent(c)
		p.position = Vector3.ZERO
		p._saddle_view.rig.skeleton.skeleton_updated.connect(_follow_saddle)
		_follow_saddle()
	else:
		p.reparent(c.view.mount_socket())
		p.position = -mount_hips_offset
	if p.anim:
		p.anim.play_clip(&"mount_idle")
	print("[capture] mounted %s" % c.def.id)

## Runs on the mount's skeleton_updated, after its clip posed the bones; following in _process lags a frame
## and the rider bounces. rider_transform() is the rider's unscaled model root, so this undoes the rig's own
## facing yaw (mesh_root) and drops the 1.18 silhouette lift, which would push the feet past the footboard.
func _follow_saddle() -> void:
	var view := p._saddle_view
	if view == null or p.rig == null or p.rig.mesh_root == null:
		return
	p.rig.global_transform = view.rider_transform() * Transform3D(p.rig.mesh_root.basis.orthonormalized().inverse())

func dismount() -> void:
	var c := p.mounted_on
	if c == null:
		return
	var view := p._saddle_view
	if view:
		if is_instance_valid(view) and view.rig.skeleton.skeleton_updated.is_connected(_follow_saddle):
			view.rig.skeleton.skeleton_updated.disconnect(_follow_saddle)
			view.end_ride()
		p._saddle_view = null
		p.rig.transform = _rig_rest
	var pos := c.global_position + Vector3(1.2, 0, 0)
	var host := _mount_saved_parent if _mount_saved_parent else c.get_parent()
	p.reparent(host)
	# reparent keeps the global transform, so the body would keep the mount's yaw and the visual (local yaw,
	# player_sim) would run sideways or backwards. Zero the body yaw; keep the facing on the visual.
	var face := p.visual.global_rotation.y if p.visual else 0.0
	p.global_rotation = Vector3.ZERO
	if p.visual:
		p.visual.global_rotation.y = face
	p.global_position = pos
	if is_instance_valid(c):
		c.ridden = false
		c.remove_collision_exception_with(p)
		p.remove_collision_exception_with(c)
	p.mounted_on = null
	print("[capture] dismounted")

## Shift held or the HUD SPRINT toggle on: the rider asks the mount to run.
func wants_mount_sprint() -> bool:
	return Input.is_action_pressed("sprint") or p.sprint_toggled

## Steer the mount. Running it goes at its pet pace (pet_record.speed, statuses, hunger; tame-21),
## walking at Creature.walk_mps of that. It moves here: the creature's own tick runs first (the rider
## is its child) and zeroes any velocity its brain did not ask for, so the rider slides it after that
## (phys-mount-01).
const MOUNT_RUN_FLOOR := 1.25

func mounted_move(delta: float) -> void:
	var m := p.mounted_on
	var dir := p.sim.cam_dir(p.sim.input_vector())
	# Shift or the SPRINT toggle runs the mount on ITS energy pool (the rider's stamina and fatigue
	# are untouched); otherwise, or once it is winded, it walks.
	var run := dir.length_squared() > 0.0 and wants_mount_sprint() and m.can_sprint()
	m.tick_energy(delta, run)
	if dir.length_squared() > 0.0:
		var speed := m.pet_record.speed / 100.0 if m.pet_record else m.move_speed_mps()
		# ASSUMPTION (owner: mounts must be worth riding): a ridden mount runs at least 1.25x the survivor's
		# sprint and walks at least her walk pace, whatever its pet speed stat says.
		speed = maxf(speed, p.sprint_speed * MOUNT_RUN_FLOOR)
		if not run:
			speed = maxf(m.walk_mps(speed), p.walk_speed)
		speed *= m.statuses.move_mult() * (0.85 if m.hunger <= 0.0 else 1.0)
		m.velocity.x = dir.x * speed
		m.velocity.z = dir.z * speed
		m.face_towards(m.global_position + dir, delta)
		if not m.anim._busy:
			m.anim.set_move_speed(speed)  # stride-matched, same as creature.gd
	else:
		m.velocity.x = 0.0
		m.velocity.z = 0.0
		if not m.anim._busy and not m.anim._forced:
			m.anim.play_idle()
	m.move_and_slide()
	if p.anim:
		p.anim._physics_tick(0.0)
