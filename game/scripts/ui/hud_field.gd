class_name HudField
extends RefCounted
## The field HUD's thumb controls and the MENU notice badge (owner 2026-10-28,
## docs/design/ui-redesign-spec.md §11): one large INTERACT hex bottom-right that shows and runs
## whatever PlayerInput.interact_choice picks (gather the nearest resource by default), a smaller
## ATTACK NEAREST hex above it (PlayerInput.attack_nearest), and the SPRINT toggle. Split out of
## hunt_hud.gd; HuntHud owns one and calls place() from _layout and tick() from _process.

## Spec §2 sizes at 1600x900 (first) and on compact canvases (phones either way up, second: every tap
## target 64 px or more there, so CLAIM grows from 52 to 64 on a phone).
# ASSUMPTION: compact canvases (UiTokens.is_compact) take the phone column; is_phone alone is portrait-only and would give 844x390 the 150 px desktop hexes.
const PX := {
	&"rail": [100.0, 64.0], &"interact": [150.0, 96.0], &"attack": [100.0, 72.0], &"sprint": [100.0, 64.0],
	&"quick": [80.0, 64.0], &"whistle": [66.0, 64.0], &"claim": [52.0, 64.0],
}
const GAP := 10.0
const BOTTOM := 8.0  ## under the INTERACT / SPRINT captions
const TICK := 0.2  ## seconds between interact_choice / attack_target rescans

## MENU badge colours: GOLD for normal notices, LIFE only for urgent ones.
# ASSUMPTION (owner undecided, spec §11): gold normal, red urgent.

static func px(kind: StringName, view: Vector2) -> float:
	return float((PX[kind] as Array)[1 if UiTokens.is_compact(view) else 0])

## Resize a hex control in place (sizes follow the canvas: a resize can cross the compact line).
static func fit(h: Control, side: float) -> void:
	if h.size.x == side and h.custom_minimum_size.x == side:
		return
	h.custom_minimum_size = Vector2(side, side)
	h.size = h.custom_minimum_size
	h.pivot_offset = h.size * 0.5
	h.queue_redraw()

var hud: HuntHud
var interact_hex: HexButton
var attack_hex: HexButton
var sprint_hex: HexButton
var choice_id: String = ""  ## what INTERACT shows now ("" = nothing in reach, the hex is disabled)
var _left := 0.0
## kind -> {"n": int, "urgent": bool}. Counts shown on the MENU hex; cleared when that sheet opens.
var notices: Dictionary = {}

func _init(owner: HuntHud) -> void:
	hud = owner
	interact_hex = _hex("InteractHex", "INTERACT", &"interact", "E")
	interact_hex.pressed.connect(press_interact)
	attack_hex = _hex("AttackNearest", "ATTACK", &"attack", "F")
	attack_hex.pressed.connect(func () -> void:
		if hud.player:
			hud.player.controls.attack_nearest())
	sprint_hex = _hex("SprintToggle", "SPRINT", &"", "Shift")
	sprint_hex.glyph = "»"
	sprint_hex.pressed.connect(func () -> void:
		if hud.player:
			sprint_hex.selected = hud.player.toggle_sprint()
			sprint_hex.queue_redraw())

func _hex(node_name: String, caption: String, icon_id: StringName, key: String) -> HexButton:
	var h := HexButton.new(64.0)
	h.name = node_name
	h.caption = caption
	if icon_id != &"":
		h.icon = UiIcons.icon(icon_id)
	h.key_hint = key
	h.rim_color = UiTokens.HUD_RIM
	hud.add_child(h)
	return h

## INTERACT pressed: pick again now (the shown pick may be 0.2 s old) and run it.
func press_interact() -> void:
	var p := hud.player
	if p == null or p.dead:
		return
	var c: Dictionary = p.controls.interact_choice()
	if c.is_empty():
		# In water with nothing offered is the salt sea (PRD :314-315): say where fresh water is.
		p.notice("Salt water: drink and wash at the river" if p.in_water else "Nothing to interact with nearby")
		return
	(c["run"] as Callable).call()
	_left = 0.0

## Bottom-right cluster. INTERACT hugs the corner; SPRINT stands left of it on the bottom line. ATTACK
## sits centred above INTERACT where the canvas has the height (desktop, portrait); on a landscape phone
## the minimap column leaves 60 px there, so it stands above SPRINT, up and left of INTERACT.
## Portrait lifts SPRINT above ATTACK (left of INTERACT is the rail).
func place(r: Vector2, inset: Vector4, map_floor: float) -> void:
	var ip := px(&"interact", r)
	var ap := px(&"attack", r)
	var sp := px(&"sprint", r)
	var cap := HuntHud.CAPTION_H
	for pair in [[interact_hex, ip], [attack_hex, ap], [sprint_hex, sp]]:
		fit(pair[0], pair[1])
	interact_hex.position = Vector2(r.x - 16.0 - inset.x - ip, r.y - BOTTOM - cap - ip - inset.y)
	var above := interact_hex.position.y - cap - 6.0 - ap
	if UiTokens.is_narrow(r):
		attack_hex.position = Vector2(interact_hex.position.x + (ip - ap) * 0.5, above)
		sprint_hex.position = Vector2(interact_hex.position.x + (ip - sp) * 0.5, above - cap - 6.0 - sp)
		return
	sprint_hex.position = Vector2(interact_hex.position.x - GAP - sp, r.y - BOTTOM - cap - sp - inset.y)
	if above >= map_floor:
		attack_hex.position = Vector2(interact_hex.position.x + (ip - ap) * 0.5, above)
	else:
		attack_hex.position = Vector2(interact_hex.position.x - 6.0 - ap, sprint_hex.position.y - cap - 6.0 - ap)

## Per frame: the sprint latch every frame (cheap), the INTERACT / ATTACK picks every TICK.
func tick(delta: float) -> void:
	var p := hud.player
	if p == null:
		return
	if sprint_hex.selected != p.sprint_toggled:
		sprint_hex.selected = p.sprint_toggled
		sprint_hex.queue_redraw()
	_left -= delta
	if _left > 0.0:
		return
	_left = TICK
	refresh()

func refresh() -> void:
	var p := hud.player
	if p == null or p.controls == null:
		return
	var c: Dictionary = p.controls.interact_choice() if not p.dead else {}
	var id := str(c.get("id", ""))
	var tex: Texture2D = c.get("icon", UiIcons.icon(&"interact"))
	var cap := str(c.get("label", "Interact")).to_upper()
	if id != choice_id or interact_hex.icon != tex or interact_hex.caption != cap:
		choice_id = id
		interact_hex.disabled = c.is_empty()
		interact_hex.icon = tex if tex else UiIcons.icon(&"interact")
		interact_hex.color_icon = bool(c.get("color_icon", false))
		interact_hex.caption = cap
		interact_hex.queue_redraw()
	var fighting := p.hunt != null and p.hunt.target != null and is_instance_valid(p.hunt.target)
	var none := p.controls.attack_target() == null
	if attack_hex.disabled != none or attack_hex.selected != fighting:
		attack_hex.disabled = none
		attack_hex.selected = fighting
		attack_hex.queue_redraw()

# ---------------------------------------------------------------- MENU notices

## A notice for the MENU badge. kind: &"skills" (unspent SP, skill level-ups), &"market" (buy/sell events:
## no client-side market hook exists yet, so nothing calls it; a market listener calls
## `HuntHud.notify_menu(&"market")`), or any other sheet's id. urgent draws the badge LIFE red.
func notify(kind: StringName, n: int = 1, urgent: bool = false) -> void:
	var row: Dictionary = notices.get(kind, {"n": 0, "urgent": false})
	row["n"] = int(row["n"]) + n
	row["urgent"] = bool(row["urgent"]) or urgent
	notices[kind] = row
	apply_badge()

## The sheet for `kind` opened: its notices are read.
func clear(kind: StringName) -> void:
	if notices.erase(kind):
		apply_badge()

## TRIBE M1: recruits waiting at the dock count on Animals (and the MENU hex) until they are accepted
## or denied; opening the screen does not clear them.
func count(kind: StringName = &"") -> int:
	if kind != &"":
		return int((notices.get(kind, {"n": 0}) as Dictionary)["n"]) + (Tribe.pending.size() if kind == &"animals" else 0)
	var n := Tribe.pending.size()
	for k in notices:
		n += int(notices[k]["n"])
	return n

func urgent() -> bool:
	for k in notices:
		if bool(notices[k]["urgent"]):
			return true
	return false

## The MENU hex's top-right badge: a count in a filled circle (HexButton.badge), GOLD with ink text,
## LIFE red with white text while any notice is urgent; none at zero.
func apply_badge() -> void:
	var m := hud._menu_hex
	if m == null:
		return
	var n := count()
	var want := "" if n <= 0 else (str(n) if n < 10 else "9+")
	m.badge = want
	m.badge_color = UiTokens.LIFE if urgent() else UiTokens.GOLD
	m.badge_ink = Color.WHITE if urgent() else UiTokens.CTA_INK
	m.queue_redraw()
