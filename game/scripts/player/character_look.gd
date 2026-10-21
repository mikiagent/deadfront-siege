class_name CharacterLook
extends RefCounted
## A survivor's look from character creation (spec 19 steps 2-3): gender, height, colours, appearance
## parts and portrait settings, as one Dictionary that the save keeps under "look". The choices come from
## data/characters/appearance.json; which colour slots this model can show comes from the masks that
## tools/blender/survivor_look_masks.py bakes (assets/characters/survivor/look/survivor_look_masks.json).
## apply() puts a look on any survivor rig: the creation preview, the portrait render and the player in
## the world. Height is visual scale only: the capsule, reach, speed and every gameplay number stay.

const APPEARANCE := "res://data/characters/appearance.json"
const LOOK_DIR := "res://assets/characters/survivor/look"
const MASKS_JSON := LOOK_DIR + "/survivor_look_masks.json"
const SHADER := "res://scripts/player/survivor_look.gdshader"
const SURVIVOR_JSON := "res://data/characters/survivor.json"
const SURVIVOR_GLB := "res://assets/characters/survivor/survivor.glb"
const SURVIVOR_ANIM_DIR := "res://assets/characters/survivor/anim"
## ASSUMPTION: the only v2 survivor is a man and no female v2 base exists yet, so a new survivor starts
## as "m"; "f" is kept and saved but shows the same model (spec 19 correction: no faked woman).
const DEFAULT_GENDER := "m"
const GENDERS := ["m", "f"]
const CHANNELS := "rgba"

static var _data: Dictionary = {}
static var _masks: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = _json(APPEARANCE)
	return _data

static func masks() -> Dictionary:
	if _masks.is_empty():
		_masks = _json(MASKS_JSON)
	return _masks

static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return parsed if parsed is Dictionary else {}

static func atlases() -> Dictionary:
	return masks().get("atlases", {})

## The atlases that have a mask region for `slot_id` ("base", "face" or a kit name).
static func atlases_with(slot_id: String) -> Array:
	var out: Array = []
	for name in atlases():
		if ((atlases()[name] as Dictionary).get("regions", {}) as Dictionary).has(slot_id):
			out.append(name)
	return out

## Colour slots that this model can actually tint: a slot no mask covers is left out (no inert slot).
static func color_slots() -> Array:
	return (data().get("color_slots", []) as Array).filter(func (s: Dictionary) -> bool: return not atlases_with(str(s.get("id", ""))).is_empty())

## Rows of "#rrggbb" for a colour slot.
static func palette(slot_id: String) -> Array:
	for s in color_slots():
		if str(s.get("id", "")) == slot_id:
			return (data().get("palettes", {}) as Dictionary).get(str(s.get("palette", "")), [])
	return []

## The painted colour of a slot's region (on the base model when it has one), the "Original" swatch.
static func painted(slot_id: String) -> Color:
	var on := atlases_with(slot_id)
	if on.is_empty():
		return Color(0.5, 0.5, 0.5)
	var region: Dictionary = ((atlases()[on[0]] as Dictionary)["regions"] as Dictionary)[slot_id]
	return Color.html(str(region.get("mean", "#808080")))

## True when only armour kits carry the slot. ASSUMPTION: Outfit Color 3 has no garment on the barefoot
## base, so it drives the kits' sleeves and trim (their arms and helmet pieces) only.
static func kit_only(slot_id: String) -> bool:
	var on := atlases_with(slot_id)
	return not on.is_empty() and not on.has("base") and not on.has("face")

static func height_range() -> Dictionary:
	return data().get("height", {"min": 1.0, "max": 1.0, "step": 0.01, "default": 1.0})

## Part slots, each with the options this gender may wear.
static func part_slots(gender: String) -> Array:
	var out: Array = []
	for s in data().get("parts", []):
		var opts: Array = (s.get("options", []) as Array).filter(func (o: Dictionary) -> bool: return gender in (o.get("genders", GENDERS) as Array))
		if not opts.is_empty():
			out.append({"id": str(s.get("id", "")), "name": str(s.get("name", "")), "options": opts})
	return out

## Part slots with something to choose between (fewer than two options shows no picker).
static func pickable_parts(gender: String) -> Array:
	return part_slots(gender).filter(func (s: Dictionary) -> bool: return (s["options"] as Array).size() >= 2)

static func patterns() -> Array:
	return (data().get("portrait", {}) as Dictionary).get("patterns", [])

static func backgrounds() -> Array:
	return (data().get("portrait", {}) as Dictionary).get("backgrounds", [])

## Kits the creation preview can try on (Durango's clothing toggles); never saved.
static func preview_outfits() -> Array:
	return data().get("preview_outfits", [{"id": "", "name": "Base clothes"}])

static func defaults(gender: String = DEFAULT_GENDER) -> Dictionary:
	var parts := {}
	for s in part_slots(gender):
		parts[s["id"]] = str((s["options"] as Array)[0].get("id", ""))
	var pd: Dictionary = (data().get("portrait", {}) as Dictionary).get("default", {})
	return {"gender": gender, "height": float(height_range().get("default", 1.0)), "colors": {}, "parts": parts,
		"portrait": {"pattern": str(pd.get("pattern", "plain")), "bg": str(pd.get("bg", "#5d6a8a"))}}

## Trust boundary (the save is user-editable): every field is coerced to a value the data offers and
## anything else falls back to the default. A save without "look" (older builds) gets the defaults.
static func clean(raw: Variant) -> Dictionary:
	var src: Dictionary = raw if raw is Dictionary else {}
	var gender := str(src.get("gender", DEFAULT_GENDER))
	if gender not in GENDERS:
		gender = DEFAULT_GENDER
	var out := defaults(gender)
	var hr := height_range()
	var h: Variant = src.get("height", out["height"])
	if (h is float or h is int) and not is_nan(float(h)):
		out["height"] = snappedf(clampf(float(h), float(hr["min"]), float(hr["max"])), float(hr.get("step", 0.01)))
	var colors: Variant = src.get("colors", {})
	if colors is Dictionary:
		for s in color_slots():
			var id := str(s["id"])
			var hex := str((colors as Dictionary).get(id, "")).to_lower()
			if hex != "" and _in_rows(palette(id), hex):
				out["colors"][id] = hex
	var parts: Variant = src.get("parts", {})
	if parts is Dictionary:
		for s in part_slots(gender):
			var want := str((parts as Dictionary).get(s["id"], ""))
			if (s["options"] as Array).any(func (o: Dictionary) -> bool: return str(o.get("id", "")) == want):
				out["parts"][s["id"]] = want
	var pt: Variant = src.get("portrait", {})
	if pt is Dictionary:
		var pat := str((pt as Dictionary).get("pattern", ""))
		if patterns().any(func (p: Dictionary) -> bool: return str(p.get("id", "")) == pat):
			out["portrait"]["pattern"] = pat
		var bg := str((pt as Dictionary).get("bg", "")).to_lower()
		if _in_rows(backgrounds(), bg):
			out["portrait"]["bg"] = bg
	return out

static func _in_rows(rows: Array, hex: String) -> bool:
	return rows.any(func (r: Variant) -> bool: return r is Array and hex in (r as Array))

## The die: every choice drawn from the data's own ranges and palettes; the gender is kept.
static func randomized(gender: String, rng: RandomNumberGenerator) -> Dictionary:
	var out := defaults(gender)
	var hr := height_range()
	var step := float(hr.get("step", 0.01))
	var steps := roundi((float(hr["max"]) - float(hr["min"])) / step)
	out["height"] = snappedf(float(hr["min"]) + float(rng.randi_range(0, steps)) * step, step)
	for s in color_slots():
		out["colors"][s["id"]] = _pick(palette(str(s["id"])), rng)
	for s in part_slots(gender):
		var opts: Array = s["options"]
		out["parts"][s["id"]] = str(opts[rng.randi_range(0, opts.size() - 1)].get("id", ""))
	var pats := patterns()
	if not pats.is_empty():
		out["portrait"]["pattern"] = str(pats[rng.randi_range(0, pats.size() - 1)].get("id", "plain"))
	out["portrait"]["bg"] = _pick(backgrounds(), rng)
	return out

static func _pick(rows: Array, rng: RandomNumberGenerator) -> String:
	var flat: Array = []
	for r in rows:
		flat.append_array(r)
	return str(flat[rng.randi_range(0, flat.size() - 1)]) if not flat.is_empty() else ""

# ---------------------------------------------------------------- applying a look to a rig

## A survivor rig built like the player's (PlayerView._setup_survivor): same GLB, clips, height and
## facing, web-safe materials, idle playing. The creation preview and the portrait render use it.
static func build_rig(parent: Node, tag: String = "look") -> RiggedModel:
	var meta: Dictionary = _json(SURVIVOR_JSON)
	var pipeline: Dictionary = meta.get("pipeline", {})
	var height := float(meta.get("height_meters", 1.78))
	var rig := RiggedModel.new()
	rig.name = "SurvivorRig"
	parent.add_child(rig)
	if not rig.setup(SURVIVOR_GLB, SURVIVOR_ANIM_DIR, str(pipeline.get("forward_axis", "+Z")), height, tag, false, float(pipeline.get("source_height_m", height))):
		return rig
	for node in rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		PlayerView.web_safe_mesh(node as MeshInstance3D)
	rig.play(&"idle")
	return rig

## Height (visual scale), colours and parts. Safe to call again with a new look; the rig keeps it, so
## pieces attached later (armour) take it through refresh().
static func apply(rig: RiggedModel, look: Dictionary) -> void:
	if rig == null or rig.skeleton == null:
		return
	rig.set_meta(&"look", look.duplicate(true))
	if not rig.has_meta(&"look_scale"):
		rig.set_meta(&"look_scale", rig.scale)
	rig.scale = (rig.get_meta(&"look_scale") as Vector3) * float(look.get("height", 1.0))
	_tint_all(rig, look.get("colors", {}))
	_attach_parts(rig, look)

## Drops a rig's surface overrides before it is freed: a skinned rig freed together with its override
## materials logs "material is null" from the headless (dummy) renderer once per mesh.
static func release(rig: RiggedModel) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	for node in rig.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.get_surface_override_material_count():
			mi.set_surface_override_material(s, null)

## Re-tints a rig with the look it already has (PlayerEquipment calls it after attaching a piece).
static func refresh(rig: RiggedModel) -> void:
	if rig != null and rig.has_meta(&"look"):
		_tint_all(rig, (rig.get_meta(&"look") as Dictionary).get("colors", {}))

static func _tint_all(rig: RiggedModel, colors: Dictionary) -> void:
	var shown := with_lips(colors)
	for node in rig.find_children("*", "MeshInstance3D", true, false):
		_tint(node as MeshInstance3D, shown)

## The lips sit outside the skin mask, so a new skin tone left them as painted (pale on a dark face,
## red on a pale one). Without a chosen lip colour they follow the skin: the painted lip colour scaled
## by chosen skin over painted skin, in linear light. Shown only; the saved look is unchanged.
static func with_lips(colors: Dictionary) -> Dictionary:
	if not colors.has("skin") or colors.has("lips") or atlases_with("lips").is_empty():
		return colors
	var skin := Color.html(str(colors["skin"])).srgb_to_linear()
	var painted_skin := painted("skin").srgb_to_linear()
	var lip := painted("lips").srgb_to_linear()
	var out := colors.duplicate()
	out["lips"] = Color(minf(1.0, lip.r * skin.r / maxf(painted_skin.r, 0.001)), minf(1.0, lip.g * skin.g / maxf(painted_skin.g, 0.001)),
		minf(1.0, lip.b * skin.b / maxf(painted_skin.b, 0.001))).linear_to_srgb().to_html(false)
	return out

## Swaps the plain material for the look shader on surfaces whose albedo has a mask atlas (the base
## mesh, its body regions and the armour kits), and back again when no colour is chosen, so an
## untouched look draws exactly as before.
static func _tint(mi: MeshInstance3D, colors: Dictionary) -> void:
	for s in mi.mesh.get_surface_count() if mi.mesh else 0:
		var mat := mi.get_active_material(s)
		var sm := mat as ShaderMaterial
		var plain := mat as BaseMaterial3D
		if sm and sm.has_meta(&"plain"):
			plain = sm.get_meta(&"plain") as BaseMaterial3D
		if plain == null or plain.albedo_texture == null:
			continue
		var on := _atlases_for(plain.albedo_texture.resource_path)
		if on.is_empty():
			continue
		if colors.is_empty():
			if sm and sm.has_meta(&"plain"):
				mi.set_surface_override_material(s, plain)
			continue
		if sm == null or not sm.has_meta(&"plain"):
			sm = _material_for(plain, on)
			mi.set_surface_override_material(s, sm)
		for i in on.size():
			var regions: Dictionary = (atlases()[on[i]] as Dictionary).get("regions", {})
			for id in regions:
				var hex := str(colors.get(id, ""))
				var uniform := "tint_%s%d" % ["ab"[i], CHANNELS.find(str(regions[id].get("channel", "r")))]
				sm.set_shader_parameter(uniform, Color.html(hex) if hex != "" else Color(0, 0, 0, 0))

## Up to two atlases share a texture (the base albedo has the body mask and the face mask).
static func _atlases_for(path: String) -> Array:
	var out: Array = []
	for name in atlases():
		var tex := str((atlases()[name] as Dictionary).get("texture", "#none"))
		if path.contains(tex) and out.size() < 2:
			out.append(name)
	return out

static func _material_for(plain: BaseMaterial3D, on: Array) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load(SHADER) as Shader  # ResourceLoader caches it; a static var would outlive the renderer
	sm.set_meta(&"plain", plain)
	sm.set_shader_parameter("albedo_tex", plain.albedo_texture)
	sm.set_shader_parameter("albedo_color", plain.albedo_color)
	for i in on.size():
		var atlas: Dictionary = atlases()[on[i]]
		sm.set_shader_parameter("mask_" + "ab"[i], load(LOOK_DIR + "/" + str(atlas.get("file", ""))))
		var regions: Dictionary = atlas.get("regions", {})
		for id in regions:
			var uniform := "mean_%s%d" % ["ab"[i], CHANNELS.find(str(regions[id].get("channel", "r")))]
			sm.set_shader_parameter(uniform, Color.html(str(regions[id].get("mean", "#808080"))))
	return sm

## Each part slot shows its chosen option. An option with a scene attaches through the armour slots'
## path (RiggedModel.attach_skinned, as PlayerEquipment.equip does); a mesh without a skin rides its
## attach_bone. The base model's own hair and face are option 1 with no scene: nothing to attach.
static func _attach_parts(rig: RiggedModel, look: Dictionary) -> void:
	var held: Dictionary = rig.get_meta(&"look_parts", {})
	var chosen: Dictionary = look.get("parts", {})
	for s in part_slots(str(look.get("gender", DEFAULT_GENDER))):
		var opt: Dictionary = (s["options"] as Array)[0]
		for o in s["options"]:
			if str(o.get("id", "")) == str(chosen.get(s["id"], "")):
				opt = o
		var cur: Dictionary = held.get(s["id"], {})
		if str(cur.get("id", "")) == str(opt.get("id", "")):
			continue
		for n in cur.get("nodes", []):
			if is_instance_valid(n):
				(n as Node).queue_free()
		var nodes: Array = []
		var scene := str(opt.get("scene", ""))
		if scene != "":
			for mi in RiggedModel.attach_skinned(rig.skeleton, scene):
				PlayerView.web_safe_mesh(mi)
				var bone := rig.skeleton.find_bone(str(opt.get("attach_bone", "")))
				if mi.skin == null and bone >= 0:
					var at := BoneAttachment3D.new()
					at.bone_idx = bone
					rig.skeleton.add_child(at)
					mi.reparent(at, false)
					nodes.append(at)
				else:
					nodes.append(mi)
		held[s["id"]] = {"id": str(opt.get("id", "")), "nodes": nodes}
	rig.set_meta(&"look_parts", held)
