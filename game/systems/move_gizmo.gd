extends Node3D
## 3-axis move gizmo for the Move manipulation mode.
##
## Shows three coloured arrows centred on the selected object:
##   Red    = X axis  (lateral)
##   Yellow = Y axis  (height / vertical)
##   Blue   = Z axis  (depth)
##
## Click-drag an arrow to move the target along that world axis.
## The gizmo uses _input (higher priority than _unhandled_input) so that
## arrow clicks are consumed before the selection / camera systems see them.

signal move_applied

var _target: Node3D = null
var _camera: Camera3D = null

## Arrow geometry parameters.
const ARROW_LENGTH: float = 1.2
const ARROW_SHAFT_RADIUS: float = 0.06
const ARROW_TIP_RADIUS: float = 0.15
const ARROW_TIP_HEIGHT: float = 0.30
## Cursor must be within this distance of an arrow line to register a hit.
const PICK_TOLERANCE: float = 0.25

var _dragging: bool = false
var _drag_axis: int = -1   # 0 = X, 1 = Y, 2 = Z
var _hovered_axis: int = -1
var _drag_start_world: Vector3 = Vector3.ZERO
var _target_start_pos: Vector3 = Vector3.ZERO

var _arrow_mats: Array[StandardMaterial3D] = []

## Directions for each arrow (world-space).
const _DIRECTIONS := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]

## Normal colours per arrow (semi-transparent).
const _COLORS_NORMAL := [
	Color(0.90, 0.20, 0.20, 0.85),   # red    – X
	Color(0.95, 0.85, 0.15, 0.90),   # yellow – Y (height)
	Color(0.20, 0.40, 0.90, 0.85),   # blue   – Z
]

## Brighter colours used when the cursor hovers over an arrow.
const _COLORS_HOVER := [
	Color(1.00, 0.65, 0.65, 1.00),
	Color(1.00, 1.00, 0.55, 1.00),
	Color(0.65, 0.80, 1.00, 1.00),
]


func setup(camera: Camera3D) -> void:
	_camera = camera
	_build_arrows()
	visible = false


## Attach the gizmo to [param target] and make it visible.
func show_for(target: Node3D) -> void:
	_target = target
	_dragging = false
	_drag_axis = -1
	_set_hover(-1)
	visible = (target != null and is_instance_valid(target))


## Hide the gizmo and detach from any target.
func hide_gizmo() -> void:
	_target = null
	_dragging = false
	_drag_axis = -1
	_set_hover(-1)
	visible = false


func is_dragging() -> bool:
	return _dragging


# ── Build ────────────────────────────────────────────────────────────────────

func _build_arrows() -> void:
	_arrow_mats.clear()
	for i in range(3):
		_add_arrow(i)


func _add_arrow(axis_idx: int) -> void:
	var root := Node3D.new()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _COLORS_NORMAL[axis_idx]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 2

	# Shaft (default CylinderMesh points along local +Y).
	var shaft_mi := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = ARROW_SHAFT_RADIUS
	shaft_mesh.bottom_radius = ARROW_SHAFT_RADIUS
	shaft_mesh.height = ARROW_LENGTH
	shaft_mesh.radial_segments = 8
	shaft_mesh.material = mat
	shaft_mi.mesh = shaft_mesh
	shaft_mi.position = Vector3(0, ARROW_LENGTH / 2.0, 0)
	root.add_child(shaft_mi)

	# Cone tip at the end of the shaft.
	var cone_mi := MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = ARROW_TIP_RADIUS
	cone_mesh.height = ARROW_TIP_HEIGHT
	cone_mesh.radial_segments = 12
	cone_mesh.material = mat
	cone_mi.mesh = cone_mesh
	cone_mi.position = Vector3(0, ARROW_LENGTH + ARROW_TIP_HEIGHT / 2.0, 0)
	root.add_child(cone_mi)

	# Orient the root so its local +Y points along the axis direction.
	var dir := _DIRECTIONS[axis_idx]
	if dir.is_equal_approx(Vector3.UP):
		pass  # default orientation
	elif dir.is_equal_approx(Vector3.DOWN):
		root.rotation_degrees.z = 180.0
	else:
		var axis := Vector3.UP.cross(dir).normalized()
		var angle := Vector3.UP.angle_to(dir)
		root.transform.basis = Basis(axis, angle)

	add_child(root)
	_arrow_mats.append(mat)


# ── Update ───────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not visible or not _target or not is_instance_valid(_target):
		return

	# Keep the gizmo centred on the target object.
	global_position = _target.global_position

	# Update hover highlight while not actively dragging.
	if not _dragging and _camera:
		var axis := _pick_arrow(get_viewport().get_mouse_position())
		_set_hover(axis)


# ── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible or not _target or not is_instance_valid(_target):
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not _dragging:
				var axis := _pick_arrow(mb.position)
				if axis >= 0:
					_dragging = true
					_drag_axis = axis
					_target_start_pos = _target.global_position
					_drag_start_world = _project_on_axis(mb.position, axis)
					_set_hover(axis)
					get_viewport().set_input_as_handled()
			elif not mb.pressed and _dragging:
				_dragging = false
				_drag_axis = -1
				var new_axis := _pick_arrow(mb.position)
				_set_hover(new_axis)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _dragging:
		_apply_move((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


# ── Helpers ──────────────────────────────────────────────────────────────────

## Returns the arrow index (0 = X, 1 = Y, 2 = Z) that [param screen_pos]
## overlaps, or -1 if none is within [constant PICK_TOLERANCE].
func _pick_arrow(screen_pos: Vector2) -> int:
	if not _camera:
		return -1

	var ray_o := _camera.project_ray_origin(screen_pos)
	var ray_d := _camera.project_ray_normal(screen_pos)
	var center := global_position

	var best := -1
	var best_dist := PICK_TOLERANCE

	for i in range(3):
		var dir := _DIRECTIONS[i]
		var arrow_base := center
		var arrow_tip := center + dir * (ARROW_LENGTH + ARROW_TIP_HEIGHT)

		# Point-to-line-segment closest approach between the ray and the arrow.
		var seg := arrow_tip - arrow_base
		var seg_len := seg.length()
		if seg_len < 0.001:
			continue
		var seg_dir := seg / seg_len

		var w0 := arrow_base - ray_o
		var a := seg_dir.dot(seg_dir)   # always 1
		var b := seg_dir.dot(ray_d)
		var c := ray_d.dot(ray_d)       # always 1
		var d := seg_dir.dot(w0)
		var e := ray_d.dot(w0)
		var denom := a * c - b * b
		if absf(denom) < 0.0001:
			continue

		var t_seg := (b * e - c * d) / denom
		var t_ray := (a * e - b * d) / denom

		# Clamp segment parameter.
		t_seg = clampf(t_seg, 0.0, seg_len)
		if t_ray < 0.0:
			continue

		var closest_seg := arrow_base + seg_dir * t_seg
		var closest_ray := ray_o + ray_d * t_ray
		var dist := closest_seg.distance_to(closest_ray)

		if dist < best_dist:
			best_dist = dist
			best = i

	return best


## Project the mouse ray onto the world-space axis line through the gizmo
## centre and return the closest world-space point on that line.
func _project_on_axis(screen_pos: Vector2, axis_idx: int) -> Vector3:
	if not _camera:
		return Vector3.ZERO

	var ray_from := _camera.project_ray_origin(screen_pos)
	var ray_dir := _camera.project_ray_normal(screen_pos)
	var line_origin := global_position
	var line_dir: Vector3 = _DIRECTIONS[axis_idx]

	# Closest point on the infinite axis line to the mouse ray.
	var w0 := line_origin - ray_from
	var a := line_dir.dot(line_dir)   # 1
	var b := line_dir.dot(ray_dir)
	var c := ray_dir.dot(ray_dir)     # 1
	var d := line_dir.dot(w0)
	var e := ray_dir.dot(w0)
	var denom := a * c - b * b
	if absf(denom) < 0.0001:
		return line_origin

	var t_line := (b * e - c * d) / denom
	return line_origin + line_dir * t_line


## Apply constrained movement along the dragged axis.
func _apply_move(screen_pos: Vector2) -> void:
	if not _target or not is_instance_valid(_target) or not _camera:
		return

	var current_world := _project_on_axis(screen_pos, _drag_axis)
	var delta := current_world - _drag_start_world

	# Only use the component along the drag axis.
	var axis_dir: Vector3 = _DIRECTIONS[_drag_axis]
	var axis_delta := delta.dot(axis_dir)

	# Snap to 0.25 m grid.
	axis_delta = snapped(axis_delta, 0.25)

	var new_pos := _target_start_pos + axis_dir * axis_delta
	_target.global_position = new_pos
	move_applied.emit()


func _set_hover(axis: int) -> void:
	if _hovered_axis == axis:
		return
	_hovered_axis = axis
	for i in range(_arrow_mats.size()):
		_arrow_mats[i].albedo_color = _COLORS_HOVER[i] if i == axis else _COLORS_NORMAL[i]
