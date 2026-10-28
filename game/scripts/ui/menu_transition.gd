class_name MenuTransition
extends Node
## NAVZOOM (owner: "clicking on the nav menu zooms out and parallax clouds move in"): while a menu or
## full-screen sheet is up, the follow camera eases out and three layers of soft clouds drift in over the
## world, and both ease back when it closes. One per camera, a child of it, so it frees with the world.
## Any Control can ask for it: MenuTransition.hold(node, strength) holds it while that node is in the
## tree and visible (follow() re-holds a sheet that is hidden and shown instead of freed). The strongest holder wins (the nav menu 1.0, a sheet's backdrop SHEET_STRENGTH), so the menu
## handing over to a sheet eases from one to the other instead of snapping.
## The camera's own zoom (`size`) is read once when the transition starts and written back exactly when
## it ends, so a closed menu leaves the player's zoom as it was, mid-transition closes and reopens
## included. The follow, shake and occlusion keep running: only `size` moves (the distance, near/far,
## tall-tree fade and shadow fit all follow it, as they do for pinch zoom).

## ASSUMPTION: 1.8x the camera distance at full strength, eased over 0.6 s (owner gave no numbers).
const ZOOM := 1.8
const DURATION := 0.6
## ASSUMPTION: full-screen sheets get a lighter version (1.36x, fainter clouds): they cover the world with
## a blurred dim anyway, and the nav menu handing over to one keeps part of its zoom.
const SHEET_STRENGTH := 0.45
## Cloud layers, far to near: size (fraction of view height), drift px/s at 900 px tall, alpha, count.
const LAYERS := [
	{"scale": 0.7, "speed": 9.0, "alpha": 0.5, "count": 6, "tint": Color(0.86, 0.9, 0.97)},
	{"scale": 1.1, "speed": 20.0, "alpha": 0.65, "count": 5, "tint": Color(0.95, 0.96, 0.99)},
	{"scale": 1.9, "speed": 38.0, "alpha": 0.82, "count": 4, "tint": Color(1.0, 1.0, 1.0)},
]

static var _puff: Texture2D

var cam: IsoCamera
var base_size := 0.0  ## the camera's zoom when this transition started; restored exactly at the end
var k := 0.0  ## current strength, 0..1 (eased)
var clouds: Control
var _holders: Dictionary = {}  ## holder instance id -> strength
var _from := 0.0
var _to := 0.0
var _el := 0.0
var _t := 0.0
var _seeds: Array = []  ## per layer: [[u, v, puffs:[[dx, dy, r]]], ...]

## Start (or strengthen) the transition while `holder` is in the tree. No-op without a follow camera.
static func hold(holder: Node, strength: float = 1.0) -> void:
	if holder == null or not holder.is_inside_tree():
		return
	var c := holder.get_viewport().get_camera_3d() as IsoCamera
	if c == null:
		return
	var mt := of(c)
	if mt == null:
		mt = MenuTransition.new()
		mt.cam = c
		mt.base_size = c.size
		c.add_child(mt)
	mt._holders[holder.get_instance_id()] = strength
	mt._retarget()

## Hold for `item` every time it enters the tree or is shown (sheets that hide instead of freeing).
static func follow(item: CanvasItem, strength: float) -> void:
	var sync := func () -> void:
		if item.is_visible_in_tree():
			hold(item, strength)
	item.tree_entered.connect(sync)
	item.visibility_changed.connect(sync)

## The live transition on `c`, or null.
static func of(c: Camera3D) -> MenuTransition:
	if c == null:
		return null
	var mt := c.get_node_or_null(^"MenuTransition") as MenuTransition
	return mt if mt and not mt.is_queued_for_deletion() else null

func _init() -> void:
	name = "MenuTransition"
	process_priority = -10  # before the camera's _process, so it frames the new size this frame
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	for li in LAYERS.size():
		var layer: Array = []
		for i in int(LAYERS[li]["count"]):
			var v := rng.randf()
			if li == LAYERS.size() - 1:  # the big near clouds frame the top and bottom, clear of the survivor
				v = rng.randf_range(-0.08, 0.2) if i % 2 == 0 else rng.randf_range(0.8, 1.08)
			var puffs: Array = []
			for p in 7:
				var dx := rng.randf_range(-1.0, 1.0)
				puffs.append([dx, rng.randf_range(-0.28, 0.08) * (1.0 - absf(dx) * 0.5), rng.randf_range(0.3, 0.45) + 0.25 * (1.0 - absf(dx))])
			layer.append([(float(i) + rng.randf_range(0.1, 0.9)) / float(LAYERS[li]["count"]), v, puffs])
		_seeds.append(layer)

func _ready() -> void:
	var cl := CanvasLayer.new()
	cl.name = "CloudLayer"
	# Over the 3D world and under every UI layer (the HUD is 1): the HUD comes back over the clouds as the
	# menu closes, and the nav menu (90) and sheets (96, which blur it) draw on top.
	cl.layer = -1
	add_child(cl)
	clouds = Control.new()
	clouds.name = "Clouds"
	clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clouds.draw.connect(_draw_clouds)
	cl.add_child(clouds)

## Polled, not signalled: a holder lets go when it is freed, queued for deletion, out of the tree or hidden.
func _prune() -> void:
	for id in _holders.keys():
		var n := instance_from_id(id) as Node
		if n == null or n.is_queued_for_deletion() or not n.is_inside_tree() or (n is CanvasItem and not (n as CanvasItem).is_visible_in_tree()):
			_holders.erase(id)
	_retarget()

func _retarget() -> void:
	var goal := 0.0
	for s in _holders.values():
		goal = maxf(goal, float(s))
	if is_equal_approx(goal, _to):
		return
	_from = k
	_to = goal
	_el = 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(cam):
		queue_free()
		return
	_prune()
	_el = minf(_el + delta, DURATION)
	k = lerpf(_from, _to, smoothstep(0.0, 1.0, _el / DURATION))
	_t += delta
	if _holders.is_empty() and _el >= DURATION:
		cam.size = base_size  # the exact zoom the player had
		name = "MenuTransitionDone"  # a hold() this frame starts a fresh one
		queue_free()
		return
	cam.size = minf(base_size * (1.0 + (ZOOM - 1.0) * k), maxf(base_size, IsoCamera.LAB_MAX_SIZE))
	if clouds:
		clouds.size = clouds.get_viewport_rect().size
		clouds.queue_redraw()

## Soft clouds: clusters of one radial puff texture, each layer drifting right at its own speed and
## sliding in from the screen edges as k rises (near layers further), so they part as the menu closes.
func _draw_clouds() -> void:
	if k <= 0.001:
		return
	if _puff == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.6))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 256
		gt.height = 256
		_puff = gt
	var r := clouds.size
	for li in LAYERS.size():
		var L: Dictionary = LAYERS[li]
		var unit: float = r.y * 0.36 * float(L["scale"])
		var span := r.x + unit * 4.0
		var col: Color = L["tint"]
		col.a = float(L["alpha"]) * k
		var under := Color(0.62, 0.68, 0.78, col.a * 0.3)  # a grey belly under each cloud gives it volume
		var push := (1.0 - k) * r.x * (0.35 + 0.25 * float(li))
		for c in _seeds[li]:
			var x := fposmod(float(c[0]) * span + _t * float(L["speed"]) * r.y / 900.0, span) - unit * 2.0
			x += push * (1.0 if x > r.x * 0.5 else -1.0)
			var y := float(c[1]) * r.y
			for pass_i in 2:
				for p in c[2]:
					var rad := unit * float(p[2])
					var at := Vector2(x + float(p[0]) * unit, y + (float(p[1]) + (0.12 if pass_i == 0 else 0.0)) * unit)
					clouds.draw_texture_rect(_puff, Rect2(at - Vector2(rad, rad * 0.62), Vector2(rad * 2.0, rad * 1.24)), false, under if pass_i == 0 else col)
