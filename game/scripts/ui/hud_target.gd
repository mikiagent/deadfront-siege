class_name HudTarget
extends RefCounted
## WORLDUI (owner 2026-10-31: "disappearing when you get close (health bar at the top of the screen)"):
## which creature the top-of-screen target bar shows. In order: the hunt target; on desktop the tapped
## selection; the nearest wild animal within close range; the last creature fought (40 m); and a
## MegaRex that is fighting you always takes it (its boss bar). CreaturePlates fades the floating bar of
## whatever this picks, so an animal is shown in one place at a time. Split out of hunt_hud.gd.

## ASSUMPTION: an animal comes to the top bar within 6 m of its body's edge and goes back to its floating
## bar past 8 m (the gap stops it flickering on the line).
const CLOSE_IN := 6.0
const CLOSE_OUT := 8.0
## The bar fades in over this when its creature changes.
const FADE_MS := 200

## The nearest wild animal inside the close range; kept until it leaves CLOSE_OUT.
var close: Creature
## The creature the bar shows (null: no bar).
var shown: Creature
var _since_ms := 0

## Distance from the survivor to the animal's body edge, so a MegaRex is close as soon as a compy is.
static func edge_dist(from: Vector3, c: Creature) -> float:
	return maxf(0.0, from.distance_to(c.global_position) - c.body_radius())

## Untyped: a freed animal passed as a typed argument is a script error, not false.
static func _wild(c: Object) -> bool:
	return is_instance_valid(c) and c is Creature and not (c as Creature).is_pet and not (c as Creature).health.dead

func tick_close(player: Player) -> void:
	var at := player.global_position
	if not is_instance_valid(close):
		close = null
	if close != null and (not _wild(close) or edge_dist(at, close) > CLOSE_OUT):
		close = null
	if close != null:
		return
	var best := CLOSE_IN
	for n in player.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if not _wild(c):
			continue
		var d := edge_dist(at, c)
		if d < best:
			best = d
			close = c

## `band` is the landscape phone's centre band (empty on desktop). There a merely close animal yields the
## band to the expanded quest card and to a tapped selection, whose floating bar and swords hex need the
## room above the herd (a fight still takes it).
# ASSUMPTION: on a phone a selected animal keeps its floating bar (review r3), close or not.
func pick(player: Player, band: Rect2, last_target: Object, orders_open: bool) -> Creature:
	tick_close(player)
	var t: Creature = player.hunt.target if (player.hunt and player.hunt.target and is_instance_valid(player.hunt.target)) else null
	if t == null and not band.has_area():
		t = player.controls.selection.current()  # a tap selects: its bar shows before any fight (a phone keeps the quest card)
	if t == null and close != null and not (band.has_area() and (orders_open or player.controls.selection.current() != null)):
		t = close
	if t == null and _wild(last_target) and player.global_position.distance_to((last_target as Creature).global_position) < 40.0:
		t = last_target as Creature
	var boss := MegaRexBrain.engaged_boss(player)
	if boss != null and (t == null or not t.brain is MegaRexBrain):
		t = boss  # MEGAREX: the boss bar holds the top of the screen while she fights you
	if not is_instance_valid(shown):
		shown = null
	if t != shown:
		shown = t
		_since_ms = Time.get_ticks_msec()
	return t

## 0..1 while the bar fades in on a new creature.
func fade() -> float:
	return clampf(float(Time.get_ticks_msec() - _since_ms) / float(FADE_MS), 0.0, 1.0)

## The boss tag's text for the top bar ("" for an ordinary animal).
# ASSUMPTION: the MegaRex is the one boss; its tag reads "BOSS" in the danger red.
static func boss_tag(c: Creature) -> String:
	return "BOSS" if c != null and c.brain is MegaRexBrain else ""
