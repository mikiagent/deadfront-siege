class_name PlayerInput
extends RefCounted
## Survivor controls: keys, pad and touch become PlayerActions calls. Taps pick what is under the
## pointer (stations first, then physics), hold-to-walk retargets, the interact key picks the
## nearest thing in reach, and the HUD's context hexes route here.

const HOLD_WALK_DELAY := 0.25
const HOLD_WALK_RETARGET := 0.15
const TAP_PICK_RADIUS := 1.0
const INTERACT_GATHER_RANGE := 2.6
const FORCE_CLIPS: Array[StringName] = [
	&"idle", &"walk", &"run", &"attack_primary", &"attack_heavy",
	&"hit_react", &"knockdown", &"death", &"alert",
]

var p: Player
var _hold_walk_candidate: bool = false
var _hold_walk_elapsed: float = 0.0
var _hold_walk_retarget_left: float = 0.0
var _tap_touch_index: int = -1
var _desktop_click_fallback_pending: bool = false
var _touch_context: StringName = &"explore"

func _init(player: Player) -> void:
	p = player

## Godot web can consume a desktop mouse press before it reaches _unhandled_input even when the
## canvas control ignores mouse input. Defer a fallback until GUI routing has finished;
## handle_unhandled cancels it when the normal path did receive the click.
func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_desktop_click_fallback_pending = true
			_desktop_click_fallback.call_deferred(mb.position)

func _desktop_click_fallback(pos: Vector2) -> void:
	if not _desktop_click_fallback_pending or p.dead:
		return
	_desktop_click_fallback_pending = false
	Game.pointer = pos
	# Pick stations in screen space first. Their low, open meshes often let a 3D ray pass through
	# to terrain in desktop Compatibility/WebGL even when the visible mouse is over the model.
	var best := _station_under_pointer(pos)
	if best:
		interact_tap_target(best)
		return
	# Fall back to normal physics for clicks close enough to hit the station collision directly.
	var hit := ray()
	if hit.is_empty():
		return
	var picked := pick_interactable(hit)
	if picked is CraftStation or picked is Bonfire:
		interact_tap_target(picked)

func handle_unhandled(event: InputEvent) -> void:
	if p.dead:
		return
	var placer := p.placer
	if placer and placer.placing != &"":
		if event.is_action_pressed("place_rotate"):
			placer.rotate_clockwise()
			p.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("place_confirm"):
			p.actions.place_confirm()
			p.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("place_cancel"):
			placer.cancel()
			p.get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("inventory"):
		if p.ui:
			p.ui.visible = not p.ui.visible
		return
	if event.is_action_pressed("roll"):
		p.sim.try_roll(p.sim.cam_dir(p.sim.input_vector()))
		return
	if event.is_action_pressed("attack"):
		p.actions.attack()
		return
	if event.is_action_pressed("interact"):
		interact()
		return
	if event.is_action_pressed("craft"):
		if placer.placing != &"":
			placer.cancel()
			return
		if p.craft_ui:
			p.craft_ui.toggle()
		return
	if event.is_action_pressed("bandage"):
		p.actions.use_medicine()
		return
	if event.is_action_pressed("hunt_chase"):
		if p.hunt:
			p.hunt.hold = not p.hunt.hold
		return
	if Game.lab_force_clips:
		for i in 9:
			if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_1 + i:
				_force_clip(i)
				return
	else:
		if event.is_action_pressed("tactic_1"):
			p.hunt.use_tackle()
		elif event.is_action_pressed("tactic_2"):
			p.hunt.use_kick()
		elif event.is_action_pressed("tactic_4"):
			p.hunt.use_net()
	# Feed drag positions straight to the placer in the input event. Waiting for _process added
	# a full frame of pickup latency on mobile before the ghost reacted to the finger.
	if placer.layout_mode and placer.moving != null and placer.dragging:
		if event is InputEventScreenDrag:
			placer.drag_to((event as InputEventScreenDrag).position)
			p.get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseMotion and Input.is_action_pressed("tap"):
			placer.drag_to((event as InputEventMouseMotion).position)
			p.get_viewport().set_input_as_handled()
			return
	if _is_tap_released(event):
		_tap_touch_index = -1
		_hold_walk_candidate = false
		_hold_walk_elapsed = 0.0
		if placer.layout_mode and placer.moving != null and placer.dragging:
			placer.drag_end(p)
			p.get_viewport().set_input_as_handled()
			return
	if _is_tap_pressed(event):
		_on_tap_pressed(event)

func _on_tap_pressed(event: InputEvent) -> void:
	var placer := p.placer
	if event is InputEventMouseButton:
		_desktop_click_fallback_pending = false
	if placer.layout_mode and placer.moving == null:
		# Layout mode: a tap on a building picks it up; anything else is ignored.
		if tap_blocked():
			return
		var hit := ray()
		var col: Object = hit.get("collider", null) if not hit.is_empty() else null
		var b := unwrap_tap(col) if col else null
		if b is Node3D and BuildPlacer.is_movable(b):
			placer.pick_up(b as Node3D)
		else:
			p.notice("Drag a building to move it · tap one to rotate · DONE saves.")
		_hold_walk_candidate = false
		p.get_viewport().set_input_as_handled()
		return
	if placer.placing != &"":
		_hold_walk_candidate = false
		if tap_blocked():
			return
		placer.tap_ground()
		p.get_viewport().set_input_as_handled()
		return
	if tap_blocked():
		_hold_walk_candidate = false
		return
	if p._gather_radial and p._gather_radial.is_open():
		p._gather_radial.close()  # tap outside the hexes dismisses the radial; the tap still acts
	var tap_kind := tap_world()
	_hold_walk_candidate = tap_kind == &"ground"
	_hold_walk_elapsed = 0.0
	_hold_walk_retarget_left = 0.0

func _is_tap_pressed(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _tap_touch_index == -1:
			_tap_touch_index = touch.index
			return true
		return false
	return event.is_action_pressed("tap")

func _is_tap_released(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		return not touch.pressed and touch.index == _tap_touch_index
	return event.is_action_released("tap")

func tap_blocked() -> bool:
	# Blocked only by a control that actually stops input (buttons, sheets, panels) or sits
	# inside one. Pass-through containers such as the creature plates' status rows used to
	# count as blocking, so taps near a plate silently did nothing.
	var c := p.get_viewport().gui_get_hovered_control()
	while c != null:
		if c.mouse_filter == Control.MOUSE_FILTER_STOP and c.is_visible_in_tree():
			return true
		c = c.get_parent() as Control
	return TouchControls.enabled and TouchControls.blocks_screen_point(Game.pointer)

func _station_under_pointer(pos: Vector2) -> Node3D:
	var cam := p.get_viewport().get_camera_3d()
	var best: Node3D
	var best_px := 96.0
	if cam == null:
		return null
	for node in p.get_tree().get_nodes_in_group("craft_station"):
		var st := node as Node3D
		if st == null or cam.is_position_behind(st.global_position):
			continue
		var d := cam.unproject_position(st.global_position + Vector3(0, 0.7, 0)).distance_to(pos)
		if d < best_px:
			best_px = d
			best = st
	return best

func tap_world() -> StringName:
	# Stations are low/open meshes. On desktop WebGL the ray often reaches terrain through the
	# visible bench, so accept the nearest station projected under the pointer before physics.
	var station := _station_under_pointer(Game.pointer)
	if station:
		interact_tap_target(station)
		return &"interact"
	var hit := ray()
	if hit.is_empty():
		return &""
	var picked := pick_interactable(hit)
	if picked != null:
		interact_tap_target(picked)
		return &"interact"
	_walk_to_tile(hit.position)
	return &"ground"

func _walk_to_tile(at: Vector3) -> void:
	var nav_pos := p.sim.closest_nav_point(BuildGrid.tile_centre(BuildGrid.tile_of(at), World.runtime))
	p.actions.cancel_work()
	if p.hunt:
		p.hunt.stop()
	p.nav_to(nav_pos)
	p.view.show_ground_marker(BuildGrid.tile_centre(BuildGrid.tile_of(nav_pos), World.runtime))

func interact_tap_target(col: Object) -> void:
	p.view.clear_ground_marker()
	p.actions.cancel_work()
	if not (col is Creature and not (col as Creature).is_pet) and p.hunt:
		p.hunt.stop()
	if col is HarvestNode:
		var hn := col as HarvestNode
		var opts := hn.options()
		if p._gather_radial and not opts.is_empty():
			p._gather_radial.open(hn, opts, p.inventory)  # Durango: always pick from the hexes
		else:
			if opts.size() == 1:
				hn.select_option(0)
			p.actions.begin_gather(hn)
	elif col is Corpse:
		(col as Corpse).note_tapped()
		p.actions.open_corpse_loot(col as Corpse)
	elif col is Creature:
		var c := col as Creature
		c.note_tapped()
		if Game and Game.has_method("reveal_creature_plate"):
			Game.reveal_creature_plate(c, 3.0)
		if c.is_pet:
			p.pets.interact(c)
		elif FieldTame.can_attempt(c):
			p.actions.begin_field_tame(c)
		else:
			p.actions.attack(c)
	elif col is ConstructionSite:
		# Spec 30 §7: tapping a placed site opens its sheet (Deposit / Withdraw / Work / Cancel).
		(col as ConstructionSite).interact(p)
	elif col is Bonfire or col is CraftStation:
		# Reference: tapping a station opens its recipe radial (M8e); cauterise lives in the context hexes.
		p.open_station_craft(col as Node3D)
	elif col is TamingPen:
		p.actions.pen_interact(col as TamingPen)
	elif col is Node and (col as Node).is_in_group("harbour"):
		col.open()
	elif col is Node and (col as Node).is_in_group("cargo_warp"):
		col.use(p)
	elif col is StructurePiece:
		var hud := p.get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_structure"):
			hud.open_structure(col)  # W2-BUILDSYS card: door, chest, sign, upgrade, repair, demolish
	elif col is Node and (col as Node).is_in_group("placed_building"):
		p.actions.building_interact(col)

func pick_interactable(hit: Dictionary) -> Object:
	var ray_col: Object = hit.get("collider", null)
	if is_interactable(ray_col):
		return unwrap_tap(ray_col)
	var at: Vector3 = hit.get("position", p.global_position)
	var query := PhysicsShapeQueryParameters3D.new()
	var bubble := SphereShape3D.new()
	bubble.radius = TAP_PICK_RADIUS
	query.shape = bubble
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collide_with_bodies = true
	query.collide_with_areas = true  # HarvestNode tap zones live on layer 2 (see is_interactable)
	var best: Object = null
	var best_d := 9999.0
	for row in p.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var col: Object = row.get("collider", null)
		if col is StructurePiece or not is_interactable(col):
			continue  # a piece is tapped only by a direct hit: indoors every spot is near a wall
		var n := col as Node3D
		if n == null:
			continue
		var d := n.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = unwrap_tap(col)
	return best

func unwrap_tap(col: Object) -> Object:
	if col is Area3D:
		var owner := (col as Area3D).get_parent()
		if owner is HarvestNode or owner is CraftStation or owner is Bonfire:
			return owner
	return col

func is_interactable(col: Object) -> bool:
	if col is StructurePiece:
		return (col as StructurePiece).is_tap_target()
	if col is Area3D:
		var owner := (col as Area3D).get_parent()
		if owner is HarvestNode or owner is CraftStation or owner is Bonfire:
			return true
	if col is HarvestNode or col is Corpse or col is Creature or col is Bonfire or col is CraftStation or col is TamingPen:
		return true
	if col is Node:
		var n := col as Node
		return n.is_in_group("craft_station") or n.is_in_group("harbour") or n.is_in_group("cargo_warp") or n.is_in_group("placed_building")
	return false

func tick_hold_walk(delta: float) -> void:
	if _tap_touch_index == -1 and not Input.is_action_pressed("tap"):
		_hold_walk_candidate = false
		_hold_walk_elapsed = 0.0
		return
	if not _hold_walk_candidate:
		return
	_hold_walk_elapsed += delta
	if _hold_walk_elapsed < HOLD_WALK_DELAY:
		return
	_hold_walk_retarget_left -= delta
	if _hold_walk_retarget_left > 0.0:
		return
	_hold_walk_retarget_left = HOLD_WALK_RETARGET
	if tap_blocked():
		return
	var hit := ray()
	if hit.is_empty() or is_interactable(hit.get("collider", null)):
		return
	_walk_to_tile(hit.position)

func ray() -> Dictionary:
	var cam := p.get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var mouse := Game.pointer
	var from := cam.project_ray_origin(mouse)
	# To the far plane: the perspective camera stands 90-430 m back (the old 200 m ray fell short).
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(mouse) * cam.far)
	q.exclude = [p]
	return p.get_world_3d().direct_space_state.intersect_ray(q)

func sync_touch_context() -> void:
	if TouchControls == null:
		return
	var want := _derive_touch_context()
	if want != _touch_context:
		_touch_context = want
		TouchControls.set_context(_touch_context)
	TouchControls.set_hurt_overlay(p.statuses != null and (p.statuses.has(&"bleed") or p.statuses.has(&"deep_bleed")))

func _derive_touch_context() -> StringName:
	if p.placer and p.placer.placing != &"":
		return &"place"
	if p.mounted_on and is_instance_valid(p.mounted_on):
		return &"mounted"
	if p.hunt and p.hunt.target and is_instance_valid(p.hunt.target):
		return &"hunt"
	return &"explore"

func _force_clip(i: int) -> void:
	var c := p.actions.nearest_creature(9999.0, true)
	if c:
		c.anim.play_clip(FORCE_CLIPS[i], true)

# ---------------------------------------------------------------- interact key

## E / pad A: the nearest thing in reach, in priority order. Lets a controller (or keyboard)
## player do everything a tap does without a pointer.
func interact() -> void:
	if p.mounted_on:
		p.dismount()
		return
	var sleep_spot := p.sim.nearest_sleep_spot()
	if sleep_spot and p.vitals.fatigue >= 1.0:
		p.sim.start_sleep(sleep_spot)
		return
	var pen := p._nearest_group("taming_pen") as TamingPen
	if pen and p.global_position.distance_to(pen.global_position) < 3.0:
		p.actions.pen_interact(pen)
		return
	var station := p._nearest_group("craft_station") as Node3D
	if station and p.global_position.distance_to(station.global_position) < 2.5:
		p.open_station_craft(station)
		return
	var field := p._nearest_group("field") as FieldPlot
	if field and p.global_position.distance_to(field.global_position) < 2.8:
		p.open_field(field)
		return
	var fire := p._nearest_group("bonfire") as Bonfire
	if fire and p.global_position.distance_to(fire.global_position) < 2.5:
		fire.cauterise(p)
		return
	var corpse := p._nearest_group("corpse") as Corpse
	if corpse and p.global_position.distance_to(corpse.global_position) < 2.8:
		p.actions.begin_butcher(corpse)
		return
	var harbour := p._nearest_group("harbour")
	if harbour and p.global_position.distance_to(harbour.global_position) < 4.0:
		harbour.open()
		return
	var warp := p._nearest_group("cargo_warp")
	if warp and p.global_position.distance_to(warp.global_position) < 2.8:
		warp.use(p)
		return
	var basket := p._nearest_group("basket")
	if basket and p.global_position.distance_to(basket.global_position) < 2.8:
		p.actions.building_interact(basket)
		return
	var node := _nearest_harvest_node()
	if node and p._gather_radial:
		var opts := node.options()
		if not opts.is_empty():
			p._gather_radial.open(node, opts, p.inventory)
			return
	var pet := p.pets.nearest(2.8)
	if pet:
		p.pets.interact(pet)

## The closest harvest node within reach that still has something to give.
func _nearest_harvest_node() -> HarvestNode:
	var best: HarvestNode = null
	var best_d := INTERACT_GATHER_RANGE
	for n in p.get_tree().get_nodes_in_group("harvest"):
		var hn := n as HarvestNode
		if hn == null or not is_instance_valid(hn) or hn.pool_units_left() <= 0:
			continue
		var d := p.global_position.distance_to(hn.global_position)
		if d < best_d:
			best_d = d
			best = hn
	return best

# ---------------------------------------------------------------- HUD context hexes

## Context hexes shown by the HUD, bottom-right (reference: drink/wash by water, cook at the fire…).
func context_actions() -> Array:
	var out: Array = []
	if p.mounted_on:
		out.append({"id": "dismount", "glyph": "⤓", "label": "Dismount"})
		return out
	var inv := p.inventory
	var near := func (group: String, reach: float) -> Node3D:
		var n := p._nearest_group(group)
		return n if n and p.global_position.distance_to(n.global_position) < reach else null
	var catapult := near.call("catapult", 3.01) as FieldCatapult
	if catapult and p.hunt.target != null:
		out.append({"id":"catapult_stone", "glyph":"C", "label":"Stone %d" % inv.count_of(&"stone_shot")})
		out.append({"id":"catapult_toxin", "glyph":"V", "label":"Toxin %d" % inv.count_of(&"toxin_pot")})
	var weapon := inv.equipped_weapon()
	if weapon and weapon.def() and weapon.def().range_m > 0 and p.hunt.target != null:
		out.append({"id": "fire_ranged", "glyph": "F", "label": "Fire (%d)" % inv.count_of(weapon.def().ammo_id)})
	if weapon and (inv.count_of(&"toxin_coating") > 0 or int(weapon.attributes.get("toxin_hits", 0)) > 0):
		out.append({"id": "coat_weapon", "glyph": "V", "label": "Coat (%d/3)" % int(weapon.attributes.get("toxin_hits", 0))})
	for snare in [&"rope_snare", &"heavy_snare"]:
		if inv.count_of(snare) > 0:
			out.append({"id": str(snare), "glyph": "S", "label": "Heavy snare" if snare == &"heavy_snare" else "Rope snare"})
	if WaterAccess.near_fresh(p.global_position):
		out.append({"id": "drink", "glyph": "💧", "label": "Drink"})
		out.append({"id": "wash", "glyph": "🫧", "label": "Wash"})
		if inv.count_of(&"empty_bucket") > 0:
			out.append({"id": "fill", "label": "Fill"})
	var sleep_spot := p.sim.nearest_sleep_spot()
	if sleep_spot:
		var left := int(sleep_spot.get("sleeps_left"))
		out.append({"id": "sleep", "glyph": "☾", "label": "Sleep", "uses": "" if left < 0 else str(left)})
	if near.call("bonfire", 2.8):
		out.append({"id": "cook", "glyph": "🍖", "label": "Cook"})
		if p.statuses and (p.statuses.has(&"bleed") or p.statuses.has(&"deep_bleed")):
			out.append({"id": "cauterise", "glyph": "🔥", "label": "Cauterise"})
	if near.call("corpse", 3.0):
		out.append({"id": "loot", "glyph": "🎒", "label": "Loot"})
	if near.call("harbour", 5.0):
		out.append({"id": "harbour", "glyph": "⚓", "label": "Harbour"})
	if near.call("cargo_warp", 2.8):
		out.append({"id": "warp", "glyph": "📦", "label": "Cargo warp"})
	if near.call("taming_pen", 3.0):
		out.append({"id": "pen", "glyph": "🪤", "label": "Pen"})
	if World.runtime and World.runtime.has_method("is_claimed") and not World.runtime.is_claimed(BuildGrid.tile_of(p.global_position)):
		var free := not World.free_claim_used and not World.is_home()
		out.append({"id": "claim", "glyph": "▦", "label": "Claim" if (free or inv.count_of(&"claim_stake") > 0 or World.is_home()) else "Claim (stake)"})
	return out

func context_action(id: String) -> void:
	match id:
		"catapult_stone", "catapult_toxin":
			var catapult := p._nearest_group("catapult") as FieldCatapult
			if catapult: catapult.fire(p, p.hunt.target, id == "catapult_toxin")
		"fire_ranged":
			p.hunt.fire_ranged()
		"rope_snare", "heavy_snare":
			p.actions.place_snare(StringName(id))
		"coat_weapon":
			p.actions.coat_weapon()
		"dismount":
			p.dismount()
		"drink":
			p.actions.drink()
		"fill":
			p.actions.fill_water()
		"sleep":
			p.sim.start_sleep()
		"wash":
			p.actions.wash()
		"cook":
			var fire := p._nearest_group("bonfire")
			if fire:
				p.open_station_craft(fire)
			elif p.craft_ui:
				p.craft_ui.toggle()
		"cauterise":
			var fire := p._nearest_group("bonfire") as Bonfire
			if fire:
				fire.cauterise(p)
		"loot":
			var corpse := p._nearest_group("corpse") as Corpse
			if corpse:
				corpse.note_tapped()
				p.actions.open_corpse_loot(corpse)
		"harbour":
			var h := p._nearest_group("harbour")
			if h:
				h.open()
		"warp":
			var w := p._nearest_group("cargo_warp")
			if w:
				w.use(p)
		"pen":
			var pen := p._nearest_group("taming_pen") as TamingPen
			if pen:
				p.actions.pen_interact(pen)
		"claim":
			p.actions.claim()
