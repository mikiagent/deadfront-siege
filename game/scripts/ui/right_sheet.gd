class_name RightSheet
extends Control
## The right-side pop-out panel (Durango "Craft / Build", "Construction"; docs/design/ui-redesign-spec.md
## §7 D5): a full-height column on the right edge with the shared SheetChrome header (‹ title ✕), the
## world left visible beside it. Owners add their content to `body` and call `layout(view, safe)` on
## open and resize. Shared by CraftUI and ConstructionPanel (the Bag panel on claude/mmo-bagui is the
## same shape; unify at merge).

signal back_pressed
signal close_pressed

const MIN_W_PHONE := 440.0
const MIN_W_DESK := 560.0
const MAX_W := 760.0

var header: SheetChrome
var body: Control
## Width as a share of the view; owners with two columns (ConstructionPanel) ask for more.
var share := 0.42

func _init(p_title: String = "") -> void:
	name = "RightSheet"
	mouse_filter = Control.MOUSE_FILTER_STOP  # the panel eats its taps; the world beside it stays live
	theme = SheetChrome.ui_theme()
	header = SheetChrome.new(p_title)
	header.name = "SheetHeader"
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.back_pressed.connect(func () -> void: back_pressed.emit())
	header.close_pressed.connect(func () -> void: close_pressed.emit())
	add_child(header)
	body = Control.new()
	body.name = "SheetBody"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)

## Panel width at `view`: a phone landscape keeps >= 440 px (two 64 px tap columns and labels),
## never more than the view minus a 120 px strip of world.
static func width_for(view: Vector2, p_share: float = 0.42) -> float:
	var lo := MIN_W_PHONE if UiTokens.is_compact(view) else MIN_W_DESK
	var hi := maxf(lo, view.x - 120.0)
	if p_share <= 0.6:  # a list column stays a column; the wide D3 / Construction view may take more
		hi = minf(MAX_W, hi)
	return clampf(view.x * p_share, minf(lo, view.x), hi)

## Pins the panel to the right edge (safe = right, bottom, top, left insets) and lays out the header
## and the body rect under it.
func layout(view: Vector2, safe: Vector4 = Vector4.ZERO) -> void:
	var w := width_for(view, share) + safe.x
	position = Vector2(view.x - w, 0.0)
	size = Vector2(w, view.y)
	header.layout(Vector2(w, view.y), Vector4(safe.x, safe.y, safe.z, 0.0))
	var c := UiTokens.is_compact(view)
	var g := 8.0 if c else 18.0
	body.position = Vector2(g, header.header_h + safe.z + UiTokens.TORN_MAX + (2.0 if c else 8.0))
	body.size = Vector2(w - safe.x - g * 2.0, view.y - body.position.y - safe.y - g)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(UiTokens.PANEL, 0.97))
	draw_line(Vector2(0.5, 0.0), Vector2(0.5, size.y), Color(UiTokens.GOLD, 0.35), 2.0)
