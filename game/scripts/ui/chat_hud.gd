class_name ChatHud
extends Control
## The chat's HUD side (spec 20): the CHAT hex in the HUD's bottom-left menu row (spec 21/22 put
## chat there), the log the chat screen reads, the screen itself, and a short overlay of the newest
## Region lines over the game while the screen's gold eye is on. HuntHud builds it and feeds it its
## notices and level-ups (claude-mmo-chat-hooks.patch); island arrivals come from World here.
## The overlay is this control: HUD layout checks see it while it shows, and it never takes a tap.

## Region lines the overlay shows, and for how long after they arrive.
# ASSUMPTION: the newest 4 lines for 30 s, fading over the last 2 s; System lines stay off the
# overlay because the HUD already shows them as notices and banners.
const LINES := 4
const SHOW_S := 30.0
const FADE_S := 2.0

var hud: HuntHud
var feed: ChatLog
var hex: HexButton
var screen: ChatScreen
var overlay_on := true
var _held: Player  # the survivor whose _input is off while the screen is open

static func attach(p_hud: HuntHud, net: NetClient = null) -> ChatHud:
	var c := ChatHud.new()
	c.name = "ChatHud"
	c.hud = p_hud
	c.feed = ChatLog.new(net if net else Game.net)
	p_hud.add_child(c)
	c.hex = HexButton.new(HuntHud.HEX)
	c.hex.name = "ChatHex"
	c.hex.icon = UiIcons.icon(&"chat")
	c.hex.caption = "CHAT"
	c.hex.pressed.connect(c.open)
	p_hud.add_child(c.hex)
	return c

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	feed.changed.connect(func (_ch: StringName) -> void: queue_redraw())
	if World.has_signal("island_changed"):
		World.island_changed.connect(_on_arrival)

# ASSUMPTION: an arrival on an island (harbour or load) is a System line, named as the map names it.
func _on_arrival(id: StringName) -> void:
	feed.system("Arrived at %s." % str(World.def_of(id).get("display_name", str(id).capitalize())))

func open(ch: StringName = &"") -> void:
	if screen == null:
		screen = ChatScreen.new(feed)
		screen.overlay_on = overlay_on
		screen.overlay_toggled.connect(func (on: bool) -> void: overlay_on = on)
		screen.closed.connect(_release_player)
		var layer := CanvasLayer.new()
		layer.name = "ChatLayer"
		layer.layer = 96  # with the other modal screens, above plates (58) and world UI (40)
		add_child(layer)
		layer.add_child(screen)
	# The screen takes every click, but Player._input arms PlayerInput's web click fallback on any
	# left press and only a click no control took disarms it: a tap on the rows over a craft station
	# opened its menu behind the chat. Player._input feeds nothing else.
	if _held == null and hud and hud.player and hud.player.is_processing_input():
		_held = hud.player
		_held.set_process_input(false)
	screen.open(ch if ch != &"" else screen.channel)

func _release_player() -> void:
	if is_instance_valid(_held):
		_held.set_process_input(true)
	_held = null

func _exit_tree() -> void:
	_release_player()

## The overlay's lines: the newest Region lines still inside SHOW_S.
func fresh() -> Array:
	var out: Array = []
	var now := feed.now()
	var rows: Array = feed.lines[ChatLog.REGION]
	for i in range(rows.size() - 1, -1, -1):
		if out.size() >= LINES or now - float(rows[i]["ts"]) >= SHOW_S:
			break
		out.push_front(rows[i])
	return out

func _process(_delta: float) -> void:
	var rows := fresh() if overlay_on and (screen == null or not screen.visible) else []
	var show := not rows.is_empty()
	if visible != show:
		visible = show
	if not show:
		return
	var view := get_viewport_rect().size
	var compact := UiTokens.is_compact(view)
	var px := _px(view)
	var w := 300.0 if compact else 400.0
	var h := float(rows.size()) * (px + 8.0) + 8.0
	# Stands on the bottom-left hex stack (the menu row, or the quick-food row while it shows).
	var top := hex.position.y if hex else view.y
	if hud:
		for fh: HexButton in hud._food_hexes:
			if fh.visible:
				top = minf(top, fh.position.y)
	var inset := UiTokens.safe_insets(get_viewport())
	var box := _clear_spot(Rect2(16.0 + inset.w, top - 10.0 - h, w, h), 200.0 if compact else 260.0)
	position = box.position
	size = box.size
	queue_redraw()

## Keeps the overlay off the HUD's own blocks and hexes (HANDS stood in it at 844x390): a block to
## the right of a usable width cuts the box short, anything else lifts it above that block.
func _clear_spot(box: Rect2, min_w: float) -> Rect2:
	if hud == null:
		return box
	var mine := get_global_rect()
	var taken := HudLayout.taken_rects(hud, ["toast", "notice", "pill"]).filter(func (r: Rect2) -> bool: return not r.is_equal_approx(mine))
	for _i in 8:
		var hit: Variant = null
		for r: Rect2 in taken:
			if r.intersects(box) and (hit == null or r.position.x < (hit as Rect2).position.x):
				hit = r
		if hit == null:
			break
		var r := hit as Rect2
		if r.position.x - 8.0 - box.position.x >= min_w:
			box.size.x = r.position.x - 8.0 - box.position.x
		else:
			box.position.y = r.position.y - 8.0 - box.size.y
	return box

func _px(view: Vector2) -> int:
	return 14 if UiTokens.is_compact(view) else 18

func _draw() -> void:
	var rows := fresh()
	if rows.is_empty():
		return
	var f := ChatScreen.font()
	var px := _px(get_viewport_rect().size)
	var lh := float(px) + 8.0
	var now := feed.now()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.32))
	var y := 4.0
	for l: Dictionary in rows:
		var a := clampf((SHOW_S - (now - float(l["ts"]))) / FADE_S, 0.0, 1.0)
		var base := Vector2(8.0, y + (lh + f.get_ascent(px) - f.get_descent(px)) * 0.5)
		var name_w := 0.0
		if str(l["from"]) != "":
			var nm := UiTokens.ellipsis(f, str(l["from"]), size.x * 0.4, px)
			draw_string(f, base, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(ChatScreen.GOLD, a))
			name_w = f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 10.0
		var x := 8.0 + name_w
		var text := str(l["text"])
		if ChatEmotes.is_emote(text):
			ChatEmotes.draw(self, text, Rect2(x, y + 3.0, lh - 6.0, lh - 6.0), a)
		else:
			draw_string(f, Vector2(x, base.y), UiTokens.ellipsis(f, text, size.x - x - 8.0, px), HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(ChatScreen.TEXT, a))
		y += lh
