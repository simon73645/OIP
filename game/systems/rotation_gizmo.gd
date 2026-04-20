extends Node3D
## 3-axis rotation gizmo displayed around the selected object.
##
## Shows three coloured rings centred on the object:
##   Red   = X axis  (tilt forward / back)
##   Green = Y axis  (spin on the floor plane)
##   Blue  = Z axis  (roll sideways)
##
## Click-drag a ring to rotate the target around that axis.
## The gizmo uses _input (higher priority than _unhandled_input) so that ring
## clicks are consumed before the selection / camera systems see them.

signal rotation_applied

var _target: Node3D = null
var _camera: Camera3D = null

## Radius of each ring in world-space metres.
const RING_RADIUS: float = 1.5
## Cursor must be within this distance of the ring line to register a hit.
const PICK_TOLERANCE: float = 0.25
## Rotation speed: degrees applied per screen pixel dragged.
const SENSITIVITY: float = 0.5

var _dragging: bool = false
var _drag_axis: int = -1    # 0 = X, 1 = Y, 2 = Z
var _hovered_axis: int = -1

var _ring_mats: Array[StandardMaterial3D] = []

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

## Plane normals used for ring hit-testing.
## X-ring lies in the YZ plane  → normal = (1, 0, 0)
## Y-ring lies in the XZ plane  → normal = (0, 1, 0)
## Z-ring lies in the XY plane  → normal = (0, 0, 1)
const _NORMALS := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]


func setup(camera: Camera3D) -> void:
	_camera = camera
	_build_rings()
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


# ── Update ───────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not visible or not _target or not is_instance_valid(_target):
		return

	# Keep the gizmo centred on the target object.
	global_position = _target.global_position

	# Update hover highlight while not actively dragging.
	if not _dragging and _camera:
		var axis := _pick_axis(get_viewport().get_mouse_position())
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
			elif not mb.pressed and _dragging:
				_dragging = false
				_drag_axis = -1
				var new_axis := _pick_axis(mb.position)
				_set_hover(new_axis)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _dragging:
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
## Each ring rotates the object around the world-space axis it visually
## represents, so the result always matches the ring you grabbed regardless
## of any prior rotation applied to the object.
##   Red   ring (X) — tilt forward/back — driven by vertical mouse movement.
##   Green ring (Y) — spin on the floor plane — driven by horizontal movement.
##   Blue  ring (Z) — roll sideways — driven by horizontal movement.
func _apply_rotation(delta: Vector2) -> void:
	if not _target or not is_instance_valid(_target):
		return
	var angle_rad: float
	match _drag_axis:
		0:  # X — tilt forward / back — driven by vertical mouse movement.
			angle_rad = delta.y * deg_to_rad(SENSITIVITY)
			_target.global_rotate(Vector3.RIGHT, angle_rad)
		1:  # Y — spin on the floor plane — driven by horizontal movement.
			angle_rad = delta.x * deg_to_rad(SENSITIVITY)
			_target.global_rotate(Vector3.UP, angle_rad)
		2:  # Z — roll sideways — driven by horizontal movement.
			angle_rad = delta.x * deg_to_rad(SENSITIVITY)
			_target.global_rotate(Vector3.BACK, angle_rad)
	rotation_applied.emit()


func _set_hover(axis: int) -> void:
	if _hovered_axis == axis:
		return
	_hovered_axis = axis
	for i in range(_ring_mats.size()):
		_ring_mats[i].albedo_color = _COLORS_HOVER[i] if i == axis else _COLORS_NORMAL[i]
