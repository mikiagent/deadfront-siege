class_name FieldTame
extends RefCounted
## Knockdown-window field taming with preferred / accepted food.

const FEED_SECONDS := 1.2
const KNOCKDOWN_EXTEND := 6.0
const FAIL_COOLDOWN := 60.0
const PREFERRED_FEED := 1.0
const ACCEPTED_FEED := 0.5
const CAPTURE_HEALTH_FRAC := 0.30
## ASSUMPTION: tier-1 species (the starter tames) need no Capture Technique, so a new survivor can
## make a first tame; every higher tier needs its technique, the same nodes nets check.
const FREE_CAPTURE_TIER := 1

## The health half of the rule on its own, for callers that hold numbers instead of a Creature
## (server intents) or that gate a low-HP collapse. Spec 09: <= 30 %, not <.
static func health_allows_capture(fraction: float) -> bool:
	return fraction <= CAPTURE_HEALTH_FRAC

## FOODTORPOR (owner 2026-10-29): "they need to be weak and they have a torpor bar ... once it reaches
## a torpor threshold it can be knocked out". Weak is spec 09's rule (stunned at any HP, or HP <= 30 %);
## knocked out = weak AND torpor at or past the threshold. Only a knocked-out animal can be netted or fed.
## `torpor_frac` is torpor / torpor max (Creature.torpor_frac()).
static func weak(hp: float, hp_max: float, stunned: bool) -> bool:
	if hp <= 0.0:
		return false
	return stunned or hp / maxf(1.0, hp_max) <= CAPTURE_HEALTH_FRAC

static func torpor_ko_frac() -> float:
	return CombatTuning.num("torpor", "ko_frac", 0.6)

static func window_open(hp: float, hp_max: float, stunned: bool, torpor_frac: float = 0.0) -> bool:
	return weak(hp, hp_max, stunned) and torpor_frac + 0.0001 >= torpor_ko_frac()

## Not dead, tameable, not already a pet, and knocked out (weak + torpor past the threshold).
static func capture_window(creature: Creature) -> bool:
	if creature == null or creature.def == null or creature.health == null:
		return false
	if creature.health.dead or not creature.def.tameable or creature.is_pet:
		return false
	return window_open(creature.health.hp, creature.health.max_hp, _stunned(creature), creature.torpor_frac())

## Weak by spec 09, ignoring torpor: the HUD uses it to say which half is still missing.
static func is_weak(creature: Creature) -> bool:
	return creature != null and creature.health != null and weak(creature.health.hp, creature.health.max_hp, _stunned(creature))

static func _stunned(creature: Creature) -> bool:
	return creature.statuses != null and creature.statuses.has(&"knockdown")

## What the survivor still has to do before the net can go (empty when it can).
static func refusal(creature: Creature) -> String:
	if creature != null and not is_weak(creature):
		return "Weaken it to %d%% health, then sedate it to capture it." % int(round(CAPTURE_HEALTH_FRAC * 100.0))
	return "Sedate it: torpor must pass %d%% to knock it out." % int(round(torpor_ko_frac() * 100.0))

static func can_attempt(creature: Creature) -> bool:
	if creature == null or creature.def == null or creature.health == null:
		return false
	if creature.health.dead or not creature.def.tameable or creature.is_pet:
		return false
	if creature.tame_cooldown_left > 0.0:
		return false
	return capture_window(creature)

## "" when this survivor may tame the species, else the hint naming the missing technique.
static func lock_reason(creature: Creature) -> String:
	if creature == null or creature.def == null:
		return ""
	var tier := creature.def.capture_tier
	if tier <= FREE_CAPTURE_TIER or Data.has_capture_technique(tier):
		return ""
	return "Needs Capture Technique %d" % tier

static func preferred_need(creature: Creature) -> StringName:
	if creature == null or creature.def == null:
		return &"berry"
	if not creature.def.preferred_food.is_empty():
		return creature.def.preferred_food[0]
	return &"berry"

## A locked species accepts no food, so callers fall through to refuse_message(), which then
## names the missing technique instead of a food.
static func food_in_bag(inv: Inventory, creature: Creature) -> StringName:
	if inv == null or creature == null or creature.def == null or lock_reason(creature) != "":
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

## "" while `player` may bond one more animal, else why not (spec 09: 3 + Animal Handling I-IV).
static func roster_full(player: Player) -> String:
	if player == null or player.bonded.size() < Data.bonded_cap():
		return ""
	return "Bonded roster full (%d / %d)" % [player.bonded.size(), Data.bonded_cap()]

## Returns {kind, text, food_id, progress, needed, odds} for the creature plate. `player` is the
## survivor the plate belongs to (the local one when null): it supplies the taming odds.
static func plate_hint(creature: Creature, inv: Inventory, player = null) -> Dictionary:
	if not can_attempt(creature):
		return {}
	if player == null:
		player = PlayerRegistry.local()
	var need := preferred_need(creature)
	# The plate is the local survivor's view; at the cap a green "Tame" led to a silent refusal.
	var locked := lock_reason(creature)
	if locked == "":
		locked = roster_full(player)
	if locked != "":
		return {
			"kind": &"need",
			"text": locked,
			"food_id": &"",  # no food icon: food cannot help until the technique is learned
			"progress": creature.tame_feeds,
			"needed": creature.feeds_needed(),
		}
	if creature.def.requires_pen:
		return {
			"kind": &"pen",
			"text": "Tame in pen",
			"food_id": need,
			"progress": creature.tame_feeds,
			"needed": creature.feeds_needed(),
		}
	var have := food_in_bag(inv, creature)
	if have == &"":
		return {
			"kind": &"need",
			"text": "needs %s" % need,
			"food_id": need,
			"progress": creature.tame_feeds,
			"needed": creature.feeds_needed(),
		}
	# The odds the plate shows are the odds the net rolls (CaptureSystem.chance_for -> TamingOdds).
	var odds := TamingOdds.odds_for(creature, player, _net_tier(inv))
	return {
		"kind": &"tame",
		"text": TamingOdds.caption(odds),
		"food_id": have if have != &"" else need,
		"progress": creature.tame_feeds,
		"needed": creature.feeds_needed(),
		"odds": odds,
	}

## The net tier in the bag, 1 when there is none: the plate reads the odds with the net the survivor
## would actually throw.
static func _net_tier(inv: Inventory) -> int:
	if inv == null:
		return 1
	var net := inv.best_capture_net()
	return net.def().capture_tier if net != null else 1

static func refuse_message(creature: Creature) -> String:
	var locked := lock_reason(creature)
	return locked if locked != "" else "needs %s" % preferred_need(creature)

static func begin_window(creature: Creature) -> void:
	if creature == null or creature.def == null:
		return
	if not creature.def.tameable or creature.is_pet:
		return
	if creature.tame_cooldown_left > 0.0:
		return
	creature.tame_feeds = 0.0
	# NATURES: this animal's window (species x its nature, Creature.tame_window_seconds()).
	creature.tame_window_left = creature.tame_window_seconds()
	creature.tame_attempting = true

static func apply_feed(player: Player, creature: Creature, food_id: StringName) -> bool:
	if player == null or not can_attempt(creature):
		return false
	if lock_reason(creature) != "":
		print("[tame] refused: %s" % lock_reason(creature))
		return false
	# Refuse before eating the food: a completed tame must have a roster slot to go to.
	var full := roster_full(player)
	if full != "":
		player.notice(full + ". Animal Handling (Survival) adds slots.")
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
	if creature.tame_feeds + 0.001 >= creature.feeds_needed():
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
	if not creature.statuses.has(&"knockdown") and creature.tame_feeds + 0.001 < creature.feeds_needed():
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
	var feeds_shown := int(ceili(creature.feeds_needed() - 0.001))
	if feeds_shown < 1:
		feeds_shown = int(round(creature.tame_feeds))
	# Preparation pays: a bait item in the bag is spent on the completed tame and raises the animal's
	# IVs, which is its grade (PetRecord.grade = genetics.overall_tier(), never stamped). ASSUMPTION:
	# the design doc says the grade improves with preparation but not by how much; bait yes / no only.
	var baited := player.inventory.consume_by_category(&"bait", 1)
	if baited and creature.genetics != null:
		var bonus := TamingOdds.prep_iv_bonus()
		for stat in CreatureGenetics.STATS:
			creature.genetics.ivs[stat] = clampi(
				int(creature.genetics.ivs.get(stat, 16)) + bonus, 0, CreatureGenetics.IV_MAX)
	# The wild level carries over (capped at PetStats.MAX_LEVEL inside from_def).
	var rec := PetRecord.from_def(creature.def, &"", creature.variant, creature.genetics, creature.level)
	rec.origin = &"tame"
	rec.nature = creature.nature_id()  # NATURES: the animal keeps its nature when tamed
	rec.tamer = player.display_name()
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
	print("[tame] %s tamed grade=%s lv=%d uid=%s feeds=%d bait=%s" % [creature.def.id, rec.grade, rec.level, rec.uid, feeds_shown, baited])
	# End the hunt before converting the target. Otherwise auto-combat keeps the new pet
	# selected and the combat plate remains forced on screen after the tame reveal.
	if player.hunt and player.hunt.target == creature:
		player.hunt.stop()
	creature.become_pet(rec)
	# Same wounds, pet-sized pool: the fraction of HP left carries over to the pet's max.
	var frac := creature.health.fraction()
	creature.health.max_hp = rec.hp
	creature.health.hp = rec.hp * frac
	creature.level = rec.level
	player.bonded.append(rec)
	player.summoned_pet = creature
	rec.summoned = true
