class_name LandmarkSeal
extends Node3D
## LANDMARKS (docs/design/island-resources.md section 5.3, A3): the sealed mouth of a dormant landmark
## (a capped vent, a sealed cave). INTERACT within rules.dormant.interact_m offers "Open (n Gold)"
## (PlayerInput.interact_choice), which calls World.open_landmark; the seal frees itself once open.
## Scenery only: never saved (the site's state lives in World.landmark_state).

var site_id: String = ""
var display_name: String = ""

static func make(site: Dictionary) -> LandmarkSeal:
	var s := LandmarkSeal.new()
	s.name = "Seal_%s" % str(site.get("id", "site"))
	s.site_id = str(site.get("id", ""))
	s.display_name = str(site.get("display", "Landmark"))
	return s

func _ready() -> void:
	add_to_group("landmark_seal")
	# ASSUMPTION: a placeholder look (a dark stone cap with a faint warp-violet rim) until the art pass.
	var cap := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.6
	mesh.bottom_radius = 2.1
	mesh.height = 0.9
	cap.mesh = mesh
	cap.position.y = 0.45
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.2, 0.24)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.18, 0.5)
	mat.emission_energy_multiplier = 0.25
	cap.material_override = mat
	add_child(cap)

## The INTERACT label: what opening costs.
func label() -> String:
	var cost := int((IslandLandmarks.rules().get("dormant", {}) as Dictionary).get("open_cost_gold", 50))
	return "Open (%d Gold)" % cost

func open_by(p: Player) -> void:
	var why := World.open_landmark(site_id)
	if p == null:
		return
	if why != "":
		p.notice(why)
	else:
		p.notice("%s opens: harvest it before it withers" % display_name)
