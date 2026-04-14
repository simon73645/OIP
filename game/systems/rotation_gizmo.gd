extends Node3D
## 3-axis rotation gizmo displayed around the selected object.
##
## Shows three coloured rings centred on the object:
##   Red   = X axis  (tilt forward / back)
##   Green = Y axis  (spin on the floor plane)
##   Blue  = Z axis  (roll sideways)
##
## Also shows a yellow vertical arrow for adjusting object height (Y position).
## Click-drag the arrow up or down to raise or lower the object.
##
## Click-drag a ring to rotate the target around that axis.
## The gizmo uses _input (higher priority than _unhandled_input) so that ring
## clicks are consumed before the selection / camera systems see them.

signal rotation_applied
## Emitted when the height arrow is dragged, changing the target's Y position.
signal height_changed

var _target: Node3D = null
var _camera: Camera3D = null

## Radius of each ring in world-space metres.
const RING_RADIUS: float = 1.5
## Cursor must be within this distance of the ring line to register a hit.
const PICK_TOLERANCE: float = 0.25
## Rotation speed: degrees applied per screen pixel dragged.
const SENSITIVITY: float = 0.5

## Height arrow parameters.
const HEIGHT_ARROW_LENGTH: float = 1.2
const HEIGHT_ARROW_RADIUS: float = 0.08
const HEIGHT_ARROW_PICK_TOLERANCE: float = 0.25

var _dragging: bool = false
var _drag_axis: int = -1    # 0 = X, 1 = Y, 2 = Z, 3 = height arrow
var _hovered_axis: int = -1

var _ring_mats: Array[StandardMaterial3D] = []

## Height arrow mesh nodes and material.
var _height_arrow: Node3D = null
var _height_arrow_mat: StandardMaterial3D = null

## Starting state for height drag.
var _height_drag_start_y: float = 0.0

## Normal colours for each ring (semi-transparent so the object shows through).
const _COLORS_NORMAL := [
	Color(0.90, 0.20, 0.20, 0.85),   # red   – X
	Color(0.20, 0.85, 0.20, 0.85),   # green – Y
	Color(0.20, 0.40, 0.90, 0.85),   # blue  – Z
]

## Brighter colours used when the cursor hovers over a ring.
const _COLORS_HOVER := [
	Color(1.00, 0.65, 0.65, 1.00),
	Color(0.65, 1.00, 0.65, 1.00),
	Color(0.65, 0.80, 1.00, 1.00),
]

## Height arrow colours (yellow / bright yellow).
const COLOR_HEIGHT_NORMAL := Color(0.95, 0.85, 0.15, 0.90)
const COLOR_HEIGHT_HOVER  := Color(1.00, 1.00, 0.55, 1.00)

## Plane normals used for ring hit-testing.
## X-ring lies in the YZ plane  → normal = (1, 0, 0)
## Y-ring lies in the XZ plane  → normal = (0, 1, 0)
## Z-ring lies in the XY plane  → normal = (0, 0, 1)
const _NORMALS := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]


func setup(camera: Camera3D) -> void:
	_camera = camera
	_build_rings()
	_build_height_arrow()
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

func _build_rings() -> void:
	_ring_mats.clear()
	for i in range(3):
		_add_ring(i)


func _add_ring(axis_idx: int) -> void:
	var mi := MeshInstance3D.new()

	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS - 0.07
	torus.outer_radius = RING_RADIUS + 0.07
	torus.rings = 64
	torus.ring_segments = 12

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _COLORS_NORMAL[axis_idx]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 2
	torus.material = mat

	mi.mesh = torus

	# Rotate each ring so it lies in the correct plane.
	# TorusMesh default orientation has the ring lying flat in the XZ plane.
	match axis_idx:
		0:  # X-axis ring — must lie in the YZ plane — rotate 90° around Z
			mi.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		1:  # Y-axis ring — already in the XZ plane — no rotation needed
			mi.rotation_degrees = Vector3.ZERO
		2:  # Z-axis ring — must lie in the XY plane — rotate 90° around X
			mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	add_child(mi)
	_ring_mats.append(mat)


func _build_height_arrow() -> void:
	_height_arrow = Node3D.new()
	_height_arrow.name = "HeightArrow"

	# Shaft (thin cylinder along local +Y).
	var shaft_mi := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = HEIGHT_ARROW_RADIUS
	shaft_mesh.bottom_radius = HEIGHT_ARROW_RADIUS
	shaft_mesh.height = HEIGHT_ARROW_LENGTH
	shaft_mesh.radial_segments = 8
	shaft_mi.mesh = shaft_mesh
	shaft_mi.position = Vector3(0, HEIGHT_ARROW_LENGTH / 2.0, 0)

	# Cone (arrow head) at the tip.
	var cone_mi := MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = HEIGHT_ARROW_RADIUS * 2.5
	cone_mesh.height = HEIGHT_ARROW_LENGTH * 0.35
	cone_mesh.radial_segments = 12
	cone_mi.mesh = cone_mesh
	cone_mi.position = Vector3(0, HEIGHT_ARROW_LENGTH + HEIGHT_ARROW_LENGTH * 0.175, 0)

	_height_arrow_mat = StandardMaterial3D.new()
	_height_arrow_mat.albedo_color = COLOR_HEIGHT_NORMAL
	_height_arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_height_arrow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_height_arrow_mat.no_depth_test = true
	_height_arrow_mat.render_priority = 3
	shaft_mesh.material = _height_arrow_mat
	cone_mesh.material = _height_arrow_mat

	_height_arrow.add_child(shaft_mi)
	_height_arrow.add_child(cone_mi)
	add_child(_height_arrow)


# ── Update ───────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not visible or not _target or not is_instance_valid(_target):
		return

	# Keep the gizmo centred on the target object.
	global_position = _target.global_position

	# Update hover highlight while not actively dragging.
	if not _dragging and _camera:
		var axis := _pick_axis(get_viewport().get_mouse_position())
		if axis < 0:
			axis = _pick_height_arrow(get_viewport().get_mouse_position())
		_set_hover(axis)


# ── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible or not _target or not is_instance_valid(_target):
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not _dragging:
				var axis := _pick_axis(mb.position)
				if axis >= 0:
					_dragging = true
					_drag_axis = axis
					_set_hover(axis)
					get_viewport().set_input_as_handled()
				else:
					var height_hit := _pick_height_arrow(mb.position)
					if height_hit == 3:
						_dragging = true
						_drag_axis = 3
						_height_drag_start_y = _target.global_position.y
						_set_hover(3)
						get_viewport().set_input_as_handled()
			elif not mb.pressed and _dragging:
				_dragging = false
				_drag_axis = -1
				var new_axis := _pick_axis(mb.position)
				if new_axis < 0:
					new_axis = _pick_height_arrow(mb.position)
				_set_hover(new_axis)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _dragging:
		if _drag_axis == 3:
			_apply_height_drag((event as InputEventMouseMotion).position)
		else:
			_apply_rotation((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()


# ── Helpers ──────────────────────────────────────────────────────────────────

## Returns the ring index (0 = X, 1 = Y, 2 = Z) that [param screen_pos]
## overlaps, or -1 if none is within [constant PICK_TOLERANCE].
func _pick_axis(screen_pos: Vector2) -> int:
	if not _camera:
		return -1

	var ray_o := _camera.project_ray_origin(screen_pos)
	var ray_d := _camera.project_ray_normal(screen_pos)
	var center := global_position

	var best := -1
	var best_dist := PICK_TOLERANCE

	for i in range(3):
		var normal: Vector3 = _NORMALS[i]
		var denom := ray_d.dot(normal)
		if abs(denom) < 0.001:
			continue  # Ray is nearly parallel to the ring plane — skip.
		var t := (center - ray_o).dot(normal) / denom
		if t < 0.0:
			continue  # Intersection is behind the camera.
		var hit := ray_o + ray_d * t
		var ring_dist: float = absf((hit - center).length() - RING_RADIUS)
		if ring_dist < best_dist:
			best_dist = ring_dist
			best = i

	return best


## Apply a rotation delta to the target based on the active drag axis
## and the 2-D mouse movement [param delta] (in screen pixels).
## Mapping rationale:
##   X-axis ring (tilt forward/back) — vertical mouse movement feels natural.
##   Y-axis ring (spin on floor plane) — horizontal mouse movement feels natural.
##   Z-axis ring (roll sideways)  — horizontal mouse movement is also used here
##     because, from the default isometric camera angle, rolling sideways is
##     most intuitive when dragging left/right.  Users can distinguish the two
##     by which ring they grab (green = Y, blue = Z).
func _apply_rotation(delta: Vector2) -> void:
	if not _target or not is_instance_valid(_target):
		return
	match _drag_axis:
		0:  # X — tilt forward / back — driven by vertical mouse movement.
			_target.rotation_degrees.x += delta.y * SENSITIVITY
		1:  # Y — spin on the floor plane — driven by horizontal movement.
			_target.rotation_degrees.y += delta.x * SENSITIVITY
		2:  # Z — roll sideways — driven by horizontal movement.
			_target.rotation_degrees.z += delta.x * SENSITIVITY
	rotation_applied.emit()


## Returns 3 (height arrow axis) if the cursor is over the height arrow,
## or -1 if not.
func _pick_height_arrow(screen_pos: Vector2) -> int:
	if not _camera or not _height_arrow:
		return -1

	var ray_o := _camera.project_ray_origin(screen_pos)
	var ray_d := _camera.project_ray_normal(screen_pos)

	# The height arrow extends from the target position upward along world +Y.
	var arrow_base := global_position
	var arrow_tip := arrow_base + Vector3(0, HEIGHT_ARROW_LENGTH + HEIGHT_ARROW_LENGTH * 0.35, 0)

	# Point-to-line-segment closest approach.
	var seg := arrow_tip - arrow_base
	var seg_len := seg.length()
	if seg_len < 0.001:
		return -1
	var seg_dir := seg / seg_len

	# Closest approach between the ray and the arrow segment.
	var w0 := arrow_base - ray_o
	var a := seg_dir.dot(seg_dir)  # always 1
	var b := seg_dir.dot(ray_d)
	var c := ray_d.dot(ray_d)      # always 1
	var d := seg_dir.dot(w0)
	var e := ray_d.dot(w0)
	var denom := a * c - b * b
	if absf(denom) < 0.0001:
		return -1

	var t_seg := (b * e - c * d) / denom
	var t_ray := (a * e - b * d) / denom

	# Clamp segment parameter.
	t_seg = clampf(t_seg, 0.0, seg_len)
	if t_ray < 0.0:
		return -1

	var closest_seg := arrow_base + seg_dir * t_seg
	var closest_ray := ray_o + ray_d * t_ray
	var dist := closest_seg.distance_to(closest_ray)

	if dist < HEIGHT_ARROW_PICK_TOLERANCE:
		return 3
	return -1


## Apply height change by projecting mouse position onto the vertical axis.
func _apply_height_drag(screen_pos: Vector2) -> void:
	if not _target or not is_instance_valid(_target) or not _camera:
		return

	# Project mouse ray onto a vertical line through the target's XZ position.
	var ray_from := _camera.project_ray_origin(screen_pos)
	var ray_dir := _camera.project_ray_normal(screen_pos)

	var line_origin := Vector3(_target.global_position.x, 0.0, _target.global_position.z)
	var line_dir := Vector3.UP

	# Closest point on the vertical line to the mouse ray.
	var w0 := line_origin - ray_from
	var a := line_dir.dot(line_dir)  # 1
	var b := line_dir.dot(ray_dir)
	var c := ray_dir.dot(ray_dir)    # 1
	var d := line_dir.dot(w0)
	var e := ray_dir.dot(w0)
	var denom := a * c - b * b
	if absf(denom) < 0.0001:
		return

	var t_line := (b * e - c * d) / denom
	# Snap to grid.
	var new_y: float = snapped(t_line, 0.25)
	_target.global_position.y = new_y
	height_changed.emit()


func _set_hover(axis: int) -> void:
	if _hovered_axis == axis:
		return
	_hovered_axis = axis
	for i in range(_ring_mats.size()):
		_ring_mats[i].albedo_color = _COLORS_HOVER[i] if i == axis else _COLORS_NORMAL[i]
	# Height arrow hover.
	if _height_arrow_mat:
		_height_arrow_mat.albedo_color = COLOR_HEIGHT_HOVER if axis == 3 else COLOR_HEIGHT_NORMAL
