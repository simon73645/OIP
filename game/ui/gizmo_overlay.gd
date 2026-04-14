extends Node3D
## Visual gizmo overlays for Move / Rotate / Scale manipulation modes.
##
## Add as a child of the selected object.  Call [method set_mode] to switch
## between the three visualisations.  Call [method clear] to hide everything.

var _mode: String = ""


func set_mode(mode: String) -> void:
	if _mode == mode:
		return
	_mode = mode
	_clear_children()
	match mode:
		"move":
			_create_move_gizmo()
		"rotate":
			_create_rotate_gizmo()
		"scale":
			_create_scale_gizmo()


func clear() -> void:
	_mode = ""
	_clear_children()


# ── Internals ────────────────────────────────────────────────────────────────

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()


## Move gizmo: three axis arrows (X red, Y green, Z blue).
func _create_move_gizmo() -> void:
	_add_arrow(Vector3.RIGHT, Color(0.9, 0.2, 0.2), 1.2)
	_add_arrow(Vector3.UP, Color(0.2, 0.9, 0.2), 1.2)
	_add_arrow(Vector3(0, 0, 1), Color(0.2, 0.2, 0.9), 1.2)


## Rotate gizmo: ring around Y axis.
func _create_rotate_gizmo() -> void:
	var mat := _make_material(Color(0.2, 0.9, 0.3, 0.8))
	var ring_radius := 1.2
	var segments := 48
	var tube_r := 0.035

	# Build a triangle-strip tube ring.
	var mi := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(segments + 1):
		var a := TAU * float(i) / float(segments)
		var cx := cos(a) * ring_radius
		var cz := sin(a) * ring_radius
		var outward := Vector3(cos(a), 0.0, sin(a))
		mesh.surface_add_vertex(Vector3(cx, tube_r, cz) + outward * tube_r)
		mesh.surface_add_vertex(Vector3(cx, -tube_r, cz) - outward * tube_r)
	mesh.surface_end()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	# Small direction cone.
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.09
	cone.height = 0.22
	tip.mesh = cone
	tip.material_override = mat
	tip.position = Vector3(ring_radius, 0.0, 0.0)
	tip.rotation_degrees.z = -90.0
	add_child(tip)


## Scale gizmo: three axis lines with cube end-handles.
func _create_scale_gizmo() -> void:
	_add_scale_handle(Vector3.RIGHT, Color(0.9, 0.2, 0.2), 1.0)
	_add_scale_handle(Vector3.UP, Color(0.2, 0.9, 0.2), 1.0)
	_add_scale_handle(Vector3(0, 0, 1), Color(0.2, 0.2, 0.9), 1.0)


# ── Arrow builder ────────────────────────────────────────────────────────────

func _add_arrow(direction: Vector3, color: Color, length: float) -> void:
	var root := Node3D.new()
	var mat := _make_material(Color(color.r, color.g, color.b, 0.85))

	# Shaft (default CylinderMesh points along local +Y).
	var shaft := MeshInstance3D.new()
	var shaft_m := CylinderMesh.new()
	shaft_m.top_radius = 0.025
	shaft_m.bottom_radius = 0.025
	shaft_m.height = length
	shaft.mesh = shaft_m
	shaft.material_override = mat
	shaft.position.y = length / 2.0
	root.add_child(shaft)

	# Cone tip.
	var tip := MeshInstance3D.new()
	var tip_m := CylinderMesh.new()
	tip_m.top_radius = 0.0
	tip_m.bottom_radius = 0.07
	tip_m.height = 0.18
	tip.mesh = tip_m
	tip.material_override = mat
	tip.position.y = length + 0.09
	root.add_child(tip)

	_orient_to_direction(root, direction)
	add_child(root)


func _add_scale_handle(direction: Vector3, color: Color, length: float) -> void:
	var root := Node3D.new()
	var mat := _make_material(Color(color.r, color.g, color.b, 0.85))

	# Shaft.
	var shaft := MeshInstance3D.new()
	var shaft_m := CylinderMesh.new()
	shaft_m.top_radius = 0.02
	shaft_m.bottom_radius = 0.02
	shaft_m.height = length
	shaft.mesh = shaft_m
	shaft.material_override = mat
	shaft.position.y = length / 2.0
	root.add_child(shaft)

	# Cube handle.
	var cube := MeshInstance3D.new()
	var cube_m := BoxMesh.new()
	cube_m.size = Vector3(0.1, 0.1, 0.1)
	cube.mesh = cube_m
	cube.material_override = mat
	cube.position.y = length
	root.add_child(cube)

	_orient_to_direction(root, direction)
	add_child(root)


# ── Helpers ──────────────────────────────────────────────────────────────────

## Orient [param node] so that its local +Y axis points along [param dir].
static func _orient_to_direction(node: Node3D, dir: Vector3) -> void:
	if dir.is_equal_approx(Vector3.UP):
		return
	if dir.is_equal_approx(Vector3.DOWN):
		node.rotation_degrees.z = 180.0
		return
	var axis := Vector3.UP.cross(dir).normalized()
	var angle := Vector3.UP.angle_to(dir)
	node.transform.basis = Basis(axis, angle)


static func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
