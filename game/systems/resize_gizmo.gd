extends Node3D
## 3D arrow resize gizmo displayed on the selected conveyor.
##
## Shows small coloured arrows for resizing straight conveyors:
##   Blue arrows  (+Z / -Z) = width adjustment
##   Red arrows   (+X / -X) = length adjustment
##
## For curved conveyors only the width arrow is shown; the radius
## is controlled via a separate UI slider.
##
## Click-drag an arrow to resize the conveyor along that axis.
## The gizmo uses _input so that arrow clicks are consumed before
## the selection / camera systems see them.

signal resize_applied

var _target: Node3D = null
var _camera: Camera3D = null

## Arrow visual parameters.
const ARROW_LENGTH: float = 0.4
const ARROW_RADIUS: float = 0.06
const PICK_TOLERANCE: float = 0.2

## Minimum drag distance before resize kicks in.
const DRAG_THRESHOLD_PX: float = 2.0

var _dragging: bool = false
## Handle being dragged: 0=+X, 1=-X, 4=+Z, 5=-Z  (matching ResizableNode3D convention)
var _drag_handle: int = -1
var _hovered_handle: int = -1

## Starting state for the drag.
var _drag_start_screen: Vector2 = Vector2.ZERO
var _drag_start_size: Vector3 = Vector3.ZERO
var _drag_start_position: Vector3 = Vector3.ZERO
## For curved conveyors.
var _drag_start_width: float = 0.0

## Arrow MeshInstance3D nodes keyed by handle ID.
var _arrows: Dictionary = {}
## Materials keyed by handle ID.
var _arrow_mats: Dictionary = {}

## Arrow colours.
const COLOR_X_NORMAL := Color(0.90, 0.20, 0.20, 0.85)
const COLOR_X_HOVER  := Color(1.00, 0.65, 0.65, 1.00)
const COLOR_Z_NORMAL := Color(0.20, 0.40, 0.90, 0.85)
const COLOR_Z_HOVER  := Color(0.65, 0.80, 1.00, 1.00)

## Whether the current target is a curved conveyor.
var _is_curved: bool = false


func setup(camera: Camera3D) -> void:
	_camera = camera
	visible = false


## Attach the gizmo to a conveyor and make it visible.
func show_for(target: Node3D) -> void:
	_target = target
	_dragging = false
	_drag_handle = -1
	_set_hover(-1)

	_is_curved = _is_curved_conveyor(target)
	_rebuild_arrows()
	_update_arrow_positions()
	visible = (target != null and is_instance_valid(target))


## Hide the gizmo.
func hide_gizmo() -> void:
	_target = null
	_dragging = false
	_drag_handle = -1
	_set_hover(-1)
	visible = false


func is_dragging() -> bool:
	return _dragging


# ── Build ────────────────────────────────────────────────────────────────────

func _rebuild_arrows() -> void:
	# Remove old arrows.
	for child in get_children():
		child.queue_free()
	_arrows.clear()
	_arrow_mats.clear()

	if _is_curved:
		# Curved conveyors: only width arrows (+Z / -Z).
		_add_arrow(4, Vector3.FORWARD, COLOR_Z_NORMAL)
		_add_arrow(5, Vector3.BACK, COLOR_Z_NORMAL)
	else:
		# Straight conveyors: length (+X / -X) and width (+Z / -Z).
		_add_arrow(0, Vector3.RIGHT, COLOR_X_NORMAL)
		_add_arrow(1, Vector3.LEFT, COLOR_X_NORMAL)
		_add_arrow(4, Vector3.FORWARD, COLOR_Z_NORMAL)
		_add_arrow(5, Vector3.BACK, COLOR_Z_NORMAL)


func _add_arrow(handle_id: int, direction: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.name = "Arrow_%d" % handle_id

	# Cone (arrow head).
	var cone_mi := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = ARROW_RADIUS * 2.0
	cone.height = ARROW_LENGTH * 0.45
	cone.radial_segments = 12
	cone_mi.mesh = cone
	# Position the cone at the tip of the shaft.
	cone_mi.position = Vector3(0, ARROW_LENGTH * 0.775, 0)

	# Shaft (thin cylinder).
	var shaft_mi := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = ARROW_RADIUS
	shaft.bottom_radius = ARROW_RADIUS
	shaft.height = ARROW_LENGTH * 0.55
	shaft.radial_segments = 8
	shaft_mi.mesh = shaft
	shaft_mi.position = Vector3(0, ARROW_LENGTH * 0.275, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 3
	cone.material = mat
	shaft.material = mat

	root.add_child(shaft_mi)
	root.add_child(cone_mi)

	# Orient the arrow to point along `direction`.
	# The cylinder mesh is Y-up by default; we rotate to face `direction`.
	if direction.is_equal_approx(Vector3.UP):
		root.rotation = Vector3.ZERO
	elif direction.is_equal_approx(Vector3.DOWN):
		root.rotation = Vector3(PI, 0, 0)
	elif direction.is_equal_approx(Vector3.RIGHT):
		root.rotation = Vector3(0, 0, -PI / 2.0)
	elif direction.is_equal_approx(Vector3.LEFT):
		root.rotation = Vector3(0, 0, PI / 2.0)
	elif direction.is_equal_approx(Vector3.FORWARD):
		root.rotation = Vector3(PI / 2.0, 0, 0)
	elif direction.is_equal_approx(Vector3.BACK):
		root.rotation = Vector3(-PI / 2.0, 0, 0)

	add_child(root)
	_arrows[handle_id] = root
	_arrow_mats[handle_id] = mat


# ── Update ───────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not visible or not _target or not is_instance_valid(_target):
		return

	_update_arrow_positions()

	# Update hover while not dragging.
	if not _dragging and _camera:
		_set_hover(_pick_handle(get_viewport().get_mouse_position()))


func _update_arrow_positions() -> void:
	if not _target or not is_instance_valid(_target):
		return

	# Keep gizmo at the target's position (no rotation — arrows stay axis-aligned
	# relative to the conveyor's local frame).
	global_position = _target.global_position
	global_rotation = _target.global_rotation

	var half_size := _get_target_half_size()

	# Position each arrow at the corresponding face.
	if _arrows.has(0):  # +X
		_arrows[0].position = Vector3(half_size.x + ARROW_LENGTH * 0.3, 0, 0)
	if _arrows.has(1):  # -X
		_arrows[1].position = Vector3(-half_size.x - ARROW_LENGTH * 0.3, 0, 0)
	if _arrows.has(4):  # +Z
		_arrows[4].position = Vector3(0, 0, half_size.z + ARROW_LENGTH * 0.3)
	if _arrows.has(5):  # -Z
		_arrows[5].position = Vector3(0, 0, -half_size.z - ARROW_LENGTH * 0.3)


# ── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible or not _target or not is_instance_valid(_target):
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not _dragging:
				var handle := _pick_handle(mb.position)
				if handle >= 0:
					_dragging = true
					_drag_handle = handle
					_drag_start_screen = mb.position
					_drag_start_size = _get_target_size()
					_drag_start_position = _target.global_position
					if _is_curved:
						_drag_start_width = _get_curved_width()
					_set_hover(handle)
					get_viewport().set_input_as_handled()
			elif not mb.pressed and _dragging:
				_dragging = false
				_drag_handle = -1
				_set_hover(_pick_handle(mb.position))
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _dragging:
		_apply_resize((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


# ── Resize logic ─────────────────────────────────────────────────────────────

func _apply_resize(screen_pos: Vector2) -> void:
	if not _target or not is_instance_valid(_target) or not _camera:
		return

	# Determine axis: handle 0,1 = X; 4,5 = Z
	var axis_index: int
	var is_positive: bool
	match _drag_handle:
		0:
			axis_index = 0; is_positive = true
		1:
			axis_index = 0; is_positive = false
		4:
			axis_index = 2; is_positive = true
		5:
			axis_index = 2; is_positive = false
		_:
			return

	# Build axis direction in world space (local axis transformed by target rotation).
	var local_axis := Vector3.ZERO
	local_axis[axis_index] = 1.0
	var world_axis := (_target.global_transform.basis * local_axis).normalized()

	# Fixed edge: the opposite face of the conveyor that should not move.
	var fixed_local := Vector3.ZERO
	fixed_local[axis_index] = _drag_start_size[axis_index] / 2.0 * (-1.0 if is_positive else 1.0)
	var fixed_world := _drag_start_position + _target.global_transform.basis * fixed_local

	# Project mouse ray onto the resize axis.
	var ray_from := _camera.project_ray_origin(screen_pos)
	var ray_dir := _camera.project_ray_normal(screen_pos)

	# Line-line closest approach to find signed distance along axis.
	var v1 := world_axis
	var v2 := ray_dir
	var v3 := fixed_world - ray_from

	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)
	var dot13 := v1.dot(v3)
	var dot22 := v2.dot(v2)
	var dot23 := v2.dot(v3)

	var denom := dot11 * dot22 - dot12 * dot12
	if absf(denom) < 0.0001:
		return

	var t1 := (dot12 * dot23 - dot22 * dot13) / denom
	var new_axis_size := absf(t1)

	if _is_curved:
		# For curved conveyors: only width (Z) is supported via arrows.
		var min_width := 0.1
		new_axis_size = maxf(new_axis_size, min_width)
		_set_curved_width(new_axis_size)
	else:
		# Straight conveyors: update via ResizableNode3D.resize().
		var new_size := _drag_start_size
		new_size[axis_index] = new_axis_size

		# Enforce minimum sizes.
		if _target is ResizableNode3D:
			var resizable := _target as ResizableNode3D
			new_size = new_size.max(resizable.size_min)

		# Compute new center so the fixed edge stays in place.
		var actual_distance := new_axis_size * (1.0 if t1 >= 0.0 else -1.0)
		var center_world := fixed_world + world_axis * (actual_distance / 2.0)

		# Keep Y from the original position.
		var new_pos := center_world
		new_pos.y = _drag_start_position.y

		_target.global_position = new_pos
		if _target is ResizableNode3D:
			(_target as ResizableNode3D).resize(new_size, _drag_handle)

	resize_applied.emit()


# ── Hit testing ──────────────────────────────────────────────────────────────

## Returns the handle ID the cursor is over, or -1 if none.
func _pick_handle(screen_pos: Vector2) -> int:
	if not _camera:
		return -1

	var ray_o := _camera.project_ray_origin(screen_pos)
	var ray_d := _camera.project_ray_normal(screen_pos)

	var best := -1
	var best_dist := PICK_TOLERANCE

	for handle_id: int in _arrows.keys():
		var arrow_node: Node3D = _arrows[handle_id]
		var arrow_center := arrow_node.global_position

		# Simple sphere test around the arrow center.
		# Find closest point on ray to arrow_center.
		var to_center := arrow_center - ray_o
		var t := to_center.dot(ray_d)
		if t < 0.0:
			continue  # Behind camera.
		var closest := ray_o + ray_d * t
		var dist := closest.distance_to(arrow_center)
		if dist < best_dist:
			best_dist = dist
			best = handle_id

	return best


# ── Hover ────────────────────────────────────────────────────────────────────

func _set_hover(handle: int) -> void:
	if _hovered_handle == handle:
		return
	_hovered_handle = handle

	for hid: int in _arrow_mats.keys():
		var mat: StandardMaterial3D = _arrow_mats[hid]
		var is_x := (hid == 0 or hid == 1)
		if hid == handle:
			mat.albedo_color = COLOR_X_HOVER if is_x else COLOR_Z_HOVER
		else:
			mat.albedo_color = COLOR_X_NORMAL if is_x else COLOR_Z_NORMAL


# ── Target helpers ───────────────────────────────────────────────────────────

func _get_target_size() -> Vector3:
	if _target is ResizableNode3D:
		return (_target as ResizableNode3D).size
	# Curved conveyors: compute approximate bounding size.
	if _is_curved:
		var conveyor := _get_curved_conveyor_node()
		if conveyor:
			var outer_r: float = conveyor.get("inner_radius") + conveyor.get("conveyor_width")
			return Vector3(outer_r * 2.0, conveyor.get("belt_height") if conveyor.get("belt_height") != null else 0.5, outer_r * 2.0)
	return Vector3.ONE


func _get_target_half_size() -> Vector3:
	return _get_target_size() / 2.0


func _is_curved_conveyor(node: Node3D) -> bool:
	if node is CurvedBeltConveyorAssembly or node is CurvedRollerConveyorAssembly:
		return true
	return false


func _get_curved_conveyor_node() -> Node:
	if not _target or not is_instance_valid(_target):
		return null
	return _target.get_node_or_null("ConveyorCorner")


func _get_curved_width() -> float:
	var conveyor := _get_curved_conveyor_node()
	if conveyor:
		return conveyor.get("conveyor_width")
	return 1.524


func _set_curved_width(new_width: float) -> void:
	var conveyor := _get_curved_conveyor_node()
	if conveyor:
		conveyor.set("conveyor_width", new_width)
		# Trigger attachment update on the assembly.
		if _target.has_method("_update_attachments"):
			_target._update_attachments()
