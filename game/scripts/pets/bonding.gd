class_name Bonding
extends RefCounted
## The one bonded-pet capacity gate (durango 09). Every path that forms a bond (field tame, pen tame,
## hatch, caged baby) goes through try_bond. Only player.bonded counts; caged or unbonded animals and
## pens never do. A skill reset that drops the cap below the roster keeps every pet and only blocks
## new bonds until the count is under the cap again.

static func cap(player: Player) -> int:
	return Data.bonded_cap(player.skills if player else null)

static func count(player: Player) -> int:
	return player.bonded.size() if player else 0

static func can_bond(player: Player) -> bool:
	return player != null and count(player) < cap(player)

## "n / cap" for the Animals screen header (integrator hook).
static func label(player: Player) -> String:
	return "%d / %d" % [count(player), cap(player)]

static func full_message(n: int, p_cap: int) -> String:
	return "Bonded animals full (%d / %d). Learn Animal Handling to bond more." % [n, p_cap]

## can_bond, plus the refusal notice when the roster is full. Call it before consuming anything.
static func check(player: Player) -> bool:
	if can_bond(player):
		return true
	var msg := full_message(count(player), cap(player))
	print("[bond] refused: %s" % msg)
	if player and player.is_inside_tree():
		player.notice(msg)
	return false

## Appends `rec` to the roster, or refuses with a notice and leaves the caller holding the animal.
static func try_bond(player: Player, rec: PetRecord) -> bool:
	if rec == null or not check(player):
		return false
	player.bonded.append(rec)
	return true
