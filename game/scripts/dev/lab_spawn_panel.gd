class_name LabSpawnPanel
extends Control
## Creature lab spawner (owner 2026-10-28: "a dinosaur selector so I can spawn them"). A SPAWN tab
## opens a panel: a dropdown of every species in game/data/creatures (model-less ones spawn as the
## box stand-in CreatureView builds and are marked "(stand-in)"), a count (1-6), a nature (or Random), an Alpha
## toggle; SPAWN drops them as a pack in front of the survivor, CLEAR ALL removes every wild animal.
## SheetChrome look, 64 px tap targets, mouse and touch.
## FIGHT LAB (owner 2026-10-30): the list shows modelled species only ("Stand-ins: on" adds the rest); GOD
## toggles Game.god_mode (key G); NEXT (key T) clears and drops the next listed species, one Aggressive
## animal that comes straight at the survivor, and the info line names its brain, moves and fight clips.

const COUNT_MAX := 6
const SPAWN_AHEAD_M := 8.0

var player: Player
var species_id: StringName = &""
var count := 1
var nature: StringName = &""  ## "" = rolled per animal
var alpha := false
## Body variant (megaloceros stag / doe, pipeline.model_variants): "" = picked per animal.
var variant: StringName = &""
var _variant_btn: Button
var _next_v := -1  ## NEXT walks a species' variants (stag, then doe) before the next species
var _panel: PanelContainer
var _species_opt: OptionButton
var _count: Label
var _nature: Button
var _alpha: Button
var _ids: Array[StringName] = []
var include_stand_ins := false
var _next_i := -1
var _stand: Button
var _god: Button
## After a spawn: the species' brain, moves and authored fight clips.
var info: Label
## Fight clips a brain plays (CreatureClips names); the info line lists which ones are authored.
## What the brains without a tactics block do (read from their scripts).
const BRAIN_MOVES := {
	"TyrantBrain": "telegraphed bite, stomp every 3rd attack, tail whip if you are behind, roar on spotting",
	"RaptorPackBrain": "pack flank, bites, heavy pounce from 4-7 m off-axis",
	"ClubTailBrain": "tail moves when you are round its rear (ankylosaurus: TAIL WHIP, TAIL SMASH, CLUB SWEEP; stegosaurus: TAIL SPIN, twice when you stay close), close moves in front and beside it (STOMP, SHOVE, TACKLE; ankylosaurus TAIL SPIN from the front; stegosaurus REAR SLAM, HIND STOMP), PIVOTS on a front foot, never backs into you; ankylosaurus JOUST from far off",
	"CreatureBrain": "attack_primary, attack_heavy after 3 primaries",
}
const FIGHT_CLIPS: Array[StringName] = [&"alert", &"attack_primary", &"attack_heavy", &"tail_swipe", &"bite_combo", &"pounce", &"kick", &"charge", &"toss", &"stalk", &"pin_stab", &"charge_turn", &"stomp", &"shove_left", &"shove_right", &"tackle", &"flank_rake", &"grab_bite", &"arm_bite", &"spit", &"spin_left", &"spin_right", &"pivot_left", &"pivot_right", &"rear_slam", &"hind_stomp_left", &"hind_stomp_right", &"tackle_lunge", &"about_left", &"about_right", &"claw_rake", &"slash_bite", &"check_left", &"check_right"]

## Every species in the data, sorted (owner 2026-10-28: "put all of the animals in the creature lab").
static func all_species() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in Data.creatures:
		out.append(StringName(id))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))  # StringName sort is not alphabetical
	return out

static func has_model(id: StringName) -> bool:
	return CreatureDef.has_model(id)

## The picker's rows: modelled species, plus the stand-ins when asked.
static func listed_species(stand_ins: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in all_species():
		if stand_ins or has_model(id):
			out.append(id)
	return out

## One line per species for the fight lab: brain, archetype, verb, tactic moves, fight clips (authored / missing).
static func moves_line(id: StringName) -> String:
	var def := Data.creature(id)
	if def == null:
		return ""
	var brain := "TyrantBrain" if id == &"tyrannosaurus" else ("ClubTailBrain" if def.archetype in [&"club_tail", &"spiked_tail"] else ("TacticalBrain" if TacticalBrain.has_tactics(def) else ("RaptorPackBrain" if def.mapped_archetype() == &"raptor_pack" else "CreatureBrain")))  # mirrors Creature._make_brain
	var seqs: Array[String] = []  # the distinct steps of its tactics sequences (strafe_left/right -> strafe)
	for q in TacticalBrain.tactics_for_def(def).get("sequences", []):
		for step in (q as Dictionary).get("steps", []):
			var st := str(step).trim_suffix("_left").trim_suffix("_right")
			if not seqs.has(st):
				seqs.append(st)
	var have: Array[String] = []
	var miss: Array[String] = []
	for clip in FIGHT_CLIPS:
		if ResourceLoader.exists("res://assets/creatures/%s/anim/%s.glb" % [id, clip]):
			have.append(str(clip))
		elif clip in CreatureClips.CONTRACT:
			miss.append(str(clip))
	return "%s: %s (%s), \"%s\" | moves: %s | clips: %s%s" % [str(id).capitalize(), brain, def.archetype, def.verb,
		", ".join(seqs) if not seqs.is_empty() else BRAIN_MOVES.get(brain, ""), ", ".join(have) if not have.is_empty() else "none",
		(" | missing (plays idle): " + ", ".join(miss)) if not miss.is_empty() else ""]

## Dropdown row text: model-less species spawn as CreatureView's box placeholder.
static func item_label(id: StringName) -> String:
	return str(id).capitalize() + ("" if has_model(id) else " (stand-in)")

func setup(p: Player) -> void:
	player = p
	theme = SheetChrome.ui_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var toggle := SheetChrome.gold_button("SPAWN")
	toggle.name = "SpawnToggle"
	toggle.custom_minimum_size = Vector2(140, SheetChrome.TAP)
	toggle.position = Vector2(16, 96)
	toggle.pressed.connect(func() -> void: _panel.visible = not _panel.visible)
	add_child(toggle)
	_god = SheetChrome.gold_button("")
	_god.name = "GodToggle"
	_god.custom_minimum_size = Vector2(140, SheetChrome.TAP)
	_god.position = Vector2(16, 96 + SheetChrome.TAP + 8)
	_god.pressed.connect(toggle_god)
	add_child(_god)
	var nxt := SheetChrome.gold_button("NEXT")
	nxt.name = "NextSpecies"
	nxt.custom_minimum_size = Vector2(140, SheetChrome.TAP)
	nxt.position = Vector2(16, 96 + 2 * (SheetChrome.TAP + 8))
	nxt.pressed.connect(next_species)
	add_child(nxt)
	_weapon_btn = SheetChrome.gold_button("WEAPON")
	_weapon_btn.name = "WeaponCycle"
	_weapon_btn.custom_minimum_size = Vector2(220, SheetChrome.TAP)
	_weapon_btn.position = Vector2(16 + 140 + 8, 96 + 2 * (SheetChrome.TAP + 8))
	_weapon_btn.pressed.connect(next_weapon)
	add_child(_weapon_btn)
	info = SheetChrome.label("", 16, UiTokens.TEXT, false)
	info.name = "MovesInfo"
	info.position = Vector2(16, 96 + 3 * (SheetChrome.TAP + 8))
	info.custom_minimum_size = Vector2(560, 0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info)
	_panel = SheetChrome.panel()
	_panel.name = "SpawnPanel"
	_panel.position = Vector2(16 + 140 + 8, 96)  # beside the toggle, so it fits a 720 px tall window
	_panel.custom_minimum_size = Vector2(340, 0)
	_panel.visible = false
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)
	col.add_child(SheetChrome.label("Species", 16, UiTokens.TEXT, true))
	_species_opt = OptionButton.new()
	_species_opt.name = "SpeciesPicker"
	_species_opt.custom_minimum_size = Vector2(320, SheetChrome.TAP)
	_species_opt.fit_to_longest_item = false
	_fill_species()
	var pop := _species_opt.get_popup()
	pop.add_theme_font_size_override("font_size", 20)
	pop.add_theme_constant_override("v_separation", int(SheetChrome.TAP) - 28)  # ~64 px touch rows at 20 px text
	pop.max_size = Vector2i(400, 64 * 6)  # scrolls past six rows so it fits a 390 px tall phone
	_species_opt.item_selected.connect(func(i: int) -> void: _pick_species(_ids[i]))
	col.add_child(_species_opt)
	_stand = SheetChrome.ghost_button("")
	_stand.name = "StandIns"
	_stand.pressed.connect(func() -> void:
		include_stand_ins = not include_stand_ins
		_fill_species())
	col.add_child(_stand)
	var row := HBoxContainer.new()
	col.add_child(row)
	var minus := SheetChrome.ghost_button("-")
	minus.custom_minimum_size = Vector2(SheetChrome.TAP, SheetChrome.TAP)
	minus.pressed.connect(func() -> void: set_count(count - 1))
	row.add_child(minus)
	_count = SheetChrome.label("", 20, UiTokens.TEXT, true)
	_count.custom_minimum_size = Vector2(96, SheetChrome.TAP)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_count)
	var plus := SheetChrome.ghost_button("+")
	plus.custom_minimum_size = Vector2(SheetChrome.TAP, SheetChrome.TAP)
	plus.pressed.connect(func() -> void: set_count(count + 1))
	row.add_child(plus)
	_nature = SheetChrome.ghost_button("")
	_nature.pressed.connect(_next_nature)
	col.add_child(_nature)
	_alpha = SheetChrome.ghost_button("")
	_alpha.pressed.connect(func() -> void:
		alpha = not alpha
		_refresh())
	_alpha.visible = "alpha" in CreatureGenetics.new()  # ALPHAS have landed when genetics carries the flag
	col.add_child(_alpha)
	_variant_btn = SheetChrome.ghost_button("")
	_variant_btn.name = "Variant"
	_variant_btn.pressed.connect(_next_variant)
	col.add_child(_variant_btn)
	var go := SheetChrome.gold_button("SPAWN")
	go.name = "SpawnGo"
	go.pressed.connect(func() -> void: spawn(species_id, count, nature, alpha, variant))
	col.add_child(go)
	var clear := SheetChrome.ghost_button("CLEAR ALL", true)
	clear.name = "ClearAll"
	clear.pressed.connect(clear_all)
	col.add_child(clear)
	if not _ids.is_empty():
		_pick_species(&"compsognathus" if _ids.has(&"compsognathus") else _ids[0])
	_refresh()

func _fill_species() -> void:
	_ids = listed_species(include_stand_ins)
	_species_opt.clear()
	for id in _ids:
		_species_opt.add_item(item_label(id))
	if not _ids.has(species_id) and not _ids.is_empty():
		species_id = _ids[0]
	_refresh()

## PARTCOMBAT: the WEAPON button (key B in the fight lab) puts the next test weapon in her hands: the one-handed Iron
## Slab Blade, the two-handed Steel Greatblade, the PRO-Class Bow (with 200 arrows), round again. (A weapon left in the
## bag still arms her, so there is no bare-hands step.)
const LAB_WEAPONS: Array[StringName] = [&"iron_slab_blade", &"steel_greatblade", &"pro_bow"]
var _weapon_btn: Button
var _weapon_i := -1

func next_weapon() -> StringName:
	_weapon_i = (_weapon_i + 1) % LAB_WEAPONS.size()
	var id := LAB_WEAPONS[_weapon_i]
	if player.inventory.count_of(id) < 1:
		player.inventory.add(ItemStack.make(id, 1, {}, 30))
	player.inventory.equip(Inventory.slot_for(Data.item(id)), id)
	var ammo := Data.item(id).ammo_id
	if ammo != &"" and player.inventory.count_of(ammo) < 50:
		player.inventory.add(ItemStack.make(ammo, 200))
	_weapon_btn.text = "WEAPON: %s" % Data.item(id).display_name
	print("[fight_lab] weapon %s" % id)
	return id

func toggle_god() -> void:
	Game.god_mode = not Game.god_mode
	_refresh()

## Clear every wild animal and drop the species after the current one in the list: one Aggressive
## animal in front of the survivor, already on it. Returns it (null when the list is empty).
func next_species() -> Creature:
	if _ids.is_empty():
		return null
	var vs := variants_of(_ids[_next_i]) if _next_i >= 0 else []
	if _next_v + 1 < vs.size():
		_next_v += 1  # the same species again, its next body (megaloceros: stag, then doe)
	else:
		_next_i = (_next_i + 1) % _ids.size()  # the first NEXT drops the first species in the list
		_next_v = 0
		vs = variants_of(_ids[_next_i])
	_pick_species(_ids[_next_i])
	variant = StringName(vs[_next_v]) if _next_v < vs.size() else &""
	_refresh()
	clear_all()
	var made := spawn(species_id, 1, &"aggressive", alpha, variant)
	if made.is_empty():
		return null
	made[0].brain.on_aggro(player)
	print("[creature_lab] next %s" % info.text)
	return made[0]

func set_count(n: int) -> void:
	count = clampi(n, 1, COUNT_MAX)
	_refresh()

func _pick_species(id: StringName) -> void:
	if id != species_id:
		variant = &""
	species_id = id
	_refresh()

## A species' body variants: megaloceros -> ["stag", "doe"]. SP-RAPTOR: texture looks too (the raptor's colour
## morphs, the stegosaurus' graded/ochre), so the owner can pick one; "alpha" stays the Alpha toggle's.
static func variants_of(id: StringName) -> Array:
	var def := Data.creature(id) if Data else null
	if def == null:
		return []
	var rows := CreatureView.model_variants(def)
	var ids: Array = rows.keys()
	ids.erase("alpha")  # SP-TRIKEALPHA: the Alpha's body comes with the Alpha toggle (Creature.spawn), not the Body pick
	ids.sort()
	ids.reverse()
	return ids

func _next_variant() -> void:
	var all: Array = [""] + variants_of(species_id)
	variant = StringName(all[(all.find(str(variant)) + 1) % all.size()])
	_refresh()

func _next_nature() -> void:
	var all: Array[StringName] = [&""]
	all.append_array(CreatureNatures.ids())
	nature = all[(all.find(nature) + 1) % all.size()]
	_refresh()

func _refresh() -> void:
	if _count == null:
		return
	_count.text = "x%d" % count
	_nature.text = "Nature: %s" % ("Random" if nature == &"" else CreatureNatures.label(nature))
	_alpha.text = "Alpha: %s" % ("ON" if alpha else "off")
	_variant_btn.visible = not variants_of(species_id).is_empty()
	_variant_btn.text = "Body: %s" % ("Random" if variant == &"" else str(variant).capitalize())
	_stand.text = "Stand-ins: %s" % ("on" if include_stand_ins else "off")
	_god.text = "GOD: %s" % ("ON" if Game.god_mode else "off")
	_species_opt.select(_ids.find(species_id))

## Drop `n` of `sp` as one pack SPAWN_AHEAD_M in front of the survivor (member 0 an alpha when asked).
func spawn(sp: StringName, n: int, nat: StringName = &"", is_alpha: bool = false, body: StringName = &"") -> Array[Creature]:
	if Data.creature(sp) == null or player == null:
		return []
	CreatureDef.allow_placeholder = true  # NOBOXES: the lab panel may drop model-less species as boxes
	var fwd := -player.visual.global_basis.z if player.visual else Vector3.FORWARD
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.01 else Vector3.FORWARD
	var s := Spawner.new()
	s.species = sp
	s.count = clampi(n, 1, COUNT_MAX)
	s.radius = 1.5 + 0.4 * float(s.count)
	s.as_pack = s.count > 1
	s.nature = nat
	s.force_alpha = is_alpha
	s.variant = body
	player.get_parent().add_child(s)
	s.global_position = player.global_position + fwd * SPAWN_AHEAD_M
	var made := s.spawn_now()
	s.queue_free()
	var vt: Dictionary = CreatureView.variant_row(Data.creature(sp), body).get("tactics", {})
	info.text = moves_line(sp) + (" [%s%s]" % [body, (": point blank %s, no straight ram" % ", ".join(vt.get("point_blank", []))) if not vt.get("charge_straight", true) else ""] if body != &"" else "")
	print("[creature_lab] spawned %d %s nature=%s alpha=%s" % [made.size(), sp, nat if nat != &"" else &"random", is_alpha])
	return made

## Remove every wild animal (pets and the mount stay).
func clear_all() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("creatures"):
		var c := node as Creature
		if c and not c.is_pet and not c.is_queued_for_deletion():
			c.queue_free()
			n += 1
	print("[creature_lab] cleared %d" % n)
	return n
