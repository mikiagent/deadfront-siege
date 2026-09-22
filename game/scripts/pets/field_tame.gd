class_name FieldTame
extends RefCounted
## Knockdown-window field taming with preferred / accepted food.

const FEED_SECONDS := 1.2
const KNOCKDOWN_EXTEND := 6.0
const FAIL_COOLDOWN := 60.0
const PREFERRED_FEED := 1.0
const ACCEPTED_FEED := 0.5
const CAPTURE_HEALTH_FRAC := 0.30

static func health_allows_capture(fraction: float) -> bool:
	return fraction < CAPTURE_HEALTH_FRAC

static func can_attempt(creature: Creature) -> bool:
	if creature == null or creature.def == null or creature.health.dead:
		return false
	if not creature.def.tameable or creature.is_pet:
		return false
	if creature.tame_cooldown_left > 0.0:
		return false
	return creature.statuses.has(&"knockdown") and health_allows_capture(creature.health.fraction())

static func preferred_need(creature: Creature) -> StringName:
	if creature == null or creature.def == null:
		return &"berry"
	if not creature.def.preferred_food.is_empty():
		return creature.def.preferred_food[0]
	return &"berry"

static func food_in_bag(inv: Inventory, creature: Creature) -> StringName:
	if inv == null or creature == null or creature.def == null:
		return &""
	for id in creature.def.preferred_food:
		if inv.find_first(id) >= 0:
			return id
	for id in creature.def.accepted_food:
		if inv.find_first(id) >= 0:
			return id
	return &""

static func feed_value(creature: Creature, food_id: StringName) -> float:
	if creature == null or creature.def == null or food_id == &"":
		return 0.0
	if food_id in creature.def.preferred_food:
		return PREFERRED_FEED
	if food_id in creature.def.accepted_food:
		return ACCEPTED_FEED
	return 0.0

static func plate_hint(creature: Creature, inv: Inventory) -> Dictionary:
	## Returns {kind, text, food_id, progress} for the creature plate.
	if not can_attempt(creature):
		return {}
	var need := preferred_need(creature)
	if creature.def.requires_pen:
		return {
			"kind": &"pen",
			"text": "Tame in pen",
			"food_id": need,
			"progress": creature.tame_feeds,
			"needed": creature.def.feeds_needed,
		}
	var have := food_in_bag(inv, creature)
	if have == &"":
		return {
			"kind": &"need",
			"text": "needs %s" % need,
			"food_id": need,
			"progress": creature.tame_feeds,
			"needed": creature.def.feeds_needed,
		}
	return {
		"kind": &"tame",
		"text": "Tame",
		"food_id": have if have != &"" else need,
		"progress": creature.tame_feeds,
		"needed": creature.def.feeds_needed,
	}

static func refuse_message(creature: Creature) -> String:
	return "needs %s" % preferred_need(creature)

static func begin_window(creature: Creature) -> void:
	if creature == null or creature.def == null:
		return
	if not creature.def.tameable or creature.is_pet:
		return
	if creature.tame_cooldown_left > 0.0:
		return
	creature.tame_feeds = 0.0
	creature.tame_window_left = creature.def.tame_window_seconds
	creature.tame_attempting = true

static func apply_feed(player: Player, creature: Creature, food_id: StringName) -> bool:
	if player == null or not can_attempt(creature):
		return false
	var value := feed_value(creature, food_id)
	if value <= 0.0:
		print("[tame] refused: %s" % refuse_message(creature))
		return false
	var idx := player.inventory.find_first(food_id)
	if idx < 0:
		print("[tame] refused: %s" % refuse_message(creature))
		return false
	player.inventory.remove_at(idx, 1)
	creature.tame_feeds += value
	creature.statuses.extend(&"knockdown", KNOCKDOWN_EXTEND)
	creature.is_capturable = true
	if creature.def.requires_pen:
		print("[tame] %s fed in field (pen required) feeds=%.1f" % [creature.def.id, creature.tame_feeds])
		return true
	if creature.tame_feeds + 0.001 >= creature.def.feeds_needed:
		_complete(player, creature)
	return true

static func tick(creature: Creature, delta: float) -> void:
	if creature == null:
		return
	if creature.tame_cooldown_left > 0.0:
		creature.tame_cooldown_left = maxf(0.0, creature.tame_cooldown_left - delta)
	if not creature.tame_attempting:
		return
	if creature.is_pet or creature.health.dead:
		creature.tame_attempting = false
		return
	creature.tame_window_left = maxf(0.0, creature.tame_window_left - delta)
	if creature.tame_window_left <= 0.0:
		fail(creature, null)
		return
	if not creature.statuses.has(&"knockdown") and creature.tame_feeds + 0.001 < creature.def.feeds_needed:
		fail(creature, null)

static func fail(creature: Creature, source: Node) -> void:
	if creature == null or not creature.tame_attempting:
		return
	creature.tame_attempting = false
	creature.tame_feeds = 0.0
	creature.tame_window_left = 0.0
	creature.tame_cooldown_left = FAIL_COOLDOWN
	if creature.statuses.has(&"knockdown"):
		creature.statuses.clear_id(&"knockdown")
		creature.anim.release_knockdown()
		creature.is_capturable = false
	creature.statuses.apply(&"enraged", source)
	print("[tame] %s failed window; enraged cooldown=%.0fs" % [creature.def.id, FAIL_COOLDOWN])

static func _complete(player: Player, creature: Creature) -> void:
	var grade := _roll_grade(randi())
	var feeds_shown := int(ceili(creature.def.feeds_needed - 0.001))
	if feeds_shown < 1:
		feeds_shown = int(round(creature.tame_feeds))
	var species_id := creature.def.id
	var variant := creature.variant
	var def := creature.def
	var rec := PetRecord.from_def(def, grade, variant, creature.genetics)
	creature.tame_attempting = false
	creature.tame_feeds = 0.0
	creature.tame_window_left = 0.0
	if creature.statuses.has(&"knockdown"):
		creature.statuses.clear_id(&"knockdown")
	elif creature.anim:
		creature.anim.release_knockdown()
	creature.is_capturable = false
	if creature.anim:
		creature.anim.play_clip(&"alert")
	print("[tame] %s tamed grade=%s feeds=%d" % [species_id, grade, feeds_shown])
	if player.bonded.size() >= Data.bonded_cap():
		var bagged := ItemStack.make(&"tamed_animal", 1, {
			"species": str(species_id),
			"variant": str(variant),
			"grade": str(rec.grade),
			"genetics": rec.genetics.to_dict(),
		})
		player.inventory.add(bagged)
		creature.queue_free()
		print("[tame] bonded cap full → bagged %s" % species_id)
		return
	# End the hunt before converting the target. Otherwise auto-combat keeps the new pet
	# selected and the combat plate remains forced on screen after the tame reveal.
	if player.hunt and player.hunt.target == creature:
		player.hunt.stop()
	creature.become_pet(rec)
	player.bonded.append(rec)
	player.summoned_pet = creature
	rec.summoned = true

static func _roll_grade(seed: int) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()
	var r := rng.randf()
	if r < 0.08:
		return &"S"
	if r < 0.28:
		return &"A"
	if r < 0.75:
		return &"B"
	return &"C"
