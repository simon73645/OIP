extends Node
## In-game object selection with action-wheel-driven manipulation modes.
##
## Left-click selects objects.  After selection an action wheel offers
## Move / Rotate / Scale.  Right-click (tap, no drag) on a selected object
## reopens the wheel.  Only the gizmo for the chosen mode is displayed.
## Delete is available via the toolbar button or Del/Backspace key.

signal selection_changed(selected_node: Node3D)
signal action_wheel_requested(screen_pos: Vector2)

const GizmoOverlayScript := preload("res://game/ui/gizmo_overlay.gd")

var _camera: Camera3D = null
var _simulation_root: Node3D = null

var _selected: Node3D = null
var _highlight_box: MeshInstance3D = null

## Toolbar mode — "select" or "delete".  Move / Rotate / Scale are handled
## exclusively via the action wheel and [member _active_mode].
var _toolbar_mode: String = "select"

## Active manipulation mode chosen from the action wheel.
var _active_mode: String = ""

# ── Move state ───────────────────────────────────────────────────────────────
var _moving: bool = false
var _move_origin: Vector3 = Vector3.ZERO
var _floor_y: float = 0.0

# ── Rotate state ─────────────────────────────────────────────────────────────
var _rotating: bool = false
var _rotate_origin_deg: float = 0.0
var _rotate_mouse_start_x: float = 0.0

# ── Scale state ──────────────────────────────────────────────────────────────
var _scaling: bool = false
var _scale_origin_size: Vector3 = Vector3.ONE
var _scale_origin_scale: Vector3 = Vector3.ONE
var _scale_mouse_start_y: float = 0.0

# ── Right-click tracking ────────────────────────────────────────────────────
var _right_pressed: bool = false
var _right_press_pos: Vector2 = Vector2.ZERO

# ── Gizmo overlay ───────────────────────────────────────────────────────────
var _gizmo: Node3D = null

# ── Deferred raycast (threaded-physics safe) ─────────────────────────────────
var _pending_select: bool = false
var _pending_select_pos: Vector2 = Vector2.ZERO
var _pending_right_click: bool = false
var _pending_right_click_pos: Vector2 = Vector2.ZERO


func setup(camera: Camera3D, simulation_root: Node3D) -> void:
	_camera = camera
	_simulation_root = simulation_root


func get_selected() -> Node3D:
	return _selected


func select(node: Node3D) -> void:
	_clear_gizmo()
	_clear_highlight()
	_cancel_active_interaction()
	_active_mode = ""
	_selected = node
	if _selected:
		_add_highlight(_selected)
	selection_changed.emit(_selected)


func deselect() -> void:
	select(null)


func is_moving() -> bool:
	return _moving


## Called by the toolbar (Select / Delete).
func set_mode(mode: String) -> void:
	_toolbar_mode = mode
	if mode != "select":
		_cancel_active_interaction()
		_active_mode = ""
		_clear_gizmo()


## Called after the action wheel selects a mode.  Shows the gizmo but does
## **not** auto-start the interaction — the user clicks again to interact.
func set_active_mode(mode: String) -> void:
	_cancel_active_interaction()
	_active_mode = mode
	_update_gizmo()


# ── Input ────────────────────────────────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	if _pending_select:
		_pending_select = false
		_handle_left_click(_pending_select_pos)
	if _pending_right_click:
		_pending_right_click = false
		_handle_right_click(_pending_right_click_pos)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# ── Left button ──────────────────────────────────────────────
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Confirm an in-progress interaction.
				if _moving:
					_moving = false
					get_viewport().set_input_as_handled()
					return
				if _rotating:
					_rotating = false
					get_viewport().set_input_as_handled()
					return
				if _scaling:
					_scaling = false
					get_viewport().set_input_as_handled()
					return

				# Defer raycast.
				_pending_select = true
				_pending_select_pos = mb.position

		# ── Right button ─────────────────────────────────────────────
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_pressed = true
				_right_press_pos = mb.position
			else:
				# Detect a tap (no drag).
				if _right_pressed and _right_press_pos.distance_to(mb.position) < 8.0:
					_pending_right_click = true
					_pending_right_click_pos = mb.position
				_right_pressed = false

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _moving and _selected:
			_update_move(mm.position)
		elif _rotating and _selected:
			_update_rotate(mm.position)
		elif _scaling and _selected:
			_update_scale(mm.position)

	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_DELETE, KEY_BACKSPACE:
					if _selected:
						_delete_selected()
						get_viewport().set_input_as_handled()
				KEY_ESCAPE:
					if _moving or _rotating or _scaling:
						_cancel_active_interaction()
					else:
						deselect()
					get_viewport().set_input_as_handled()


# ── Click handlers ───────────────────────────────────────────────────────────

func _handle_left_click(screen_pos: Vector2) -> void:
	var hit := _raycast_to_simulation_child(screen_pos)

	# Delete mode (toolbar).
	if _toolbar_mode == "delete":
		if hit:
			select(hit)
			_delete_selected()
		else:
			deselect()
		return

	# Normal select flow.
	if hit == null:
		deselect()
		return

	if hit == _selected:
		if _active_mode != "":
			# Re-enter the current interaction.
			_start_mode_interaction()
		else:
			# Show the action wheel for mode choice.
			action_wheel_requested.emit(screen_pos)
	else:
		# New object — select and show wheel.
		select(hit)
		action_wheel_requested.emit(screen_pos)


func _handle_right_click(screen_pos: Vector2) -> void:
	if not _selected:
		return
	var hit := _raycast_to_simulation_child(screen_pos)
	if hit == _selected:
		_cancel_active_interaction()
		action_wheel_requested.emit(screen_pos)


# ── Raycast helper ───────────────────────────────────────────────────────────

func _raycast_to_simulation_child(screen_pos: Vector2) -> Node3D:
	if not _camera:
		return null
	var from := _camera.project_ray_origin(screen_pos)
	var to := from + _camera.project_ray_normal(screen_pos) * 500.0
	var space := _camera.get_world_3d().direct_space_state
	if not space:
		return null
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0xFFFFFFFF
	var result := space.intersect_ray(query)
	if result.is_empty():
		return null
	var collider := result["collider"] as Node
	if not collider:
		return null
	return _find_simulation_child(collider)


func _find_simulation_child(node: Node) -> Node3D:
	if not _simulation_root:
		return null
	var current := node
	while current:
		if current.get_parent() == _simulation_root:
			return current as Node3D
		current = current.get_parent()
	return null


# ── Mode interaction ─────────────────────────────────────────────────────────

func _start_mode_interaction() -> void:
	match _active_mode:
		"move":
			_moving = true
			_move_origin = _selected.global_position
		"rotate":
			_rotating = true
			_rotate_origin_deg = _selected.rotation_degrees.y
			_rotate_mouse_start_x = get_viewport().get_mouse_position().x
		"scale":
			_scaling = true
			if _selected is ResizableNode3D:
				_scale_origin_size = (_selected as ResizableNode3D).size
			else:
				_scale_origin_scale = _selected.scale
			_scale_mouse_start_y = get_viewport().get_mouse_position().y


func _cancel_active_interaction() -> void:
	if _moving and _selected:
		_selected.global_position = _move_origin
	_moving = false
	if _rotating and _selected:
		_selected.rotation_degrees.y = _rotate_origin_deg
	_rotating = false
	if _scaling and _selected:
		if _selected is ResizableNode3D:
			(_selected as ResizableNode3D).size = _scale_origin_size
		else:
			_selected.scale = _scale_origin_scale
	_scaling = false


# ── Move ─────────────────────────────────────────────────────────────────────

func _update_move(screen_pos: Vector2) -> void:
	if not _camera or not _selected:
		return
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	if abs(dir.y) < 0.001:
		return
	var t := (_floor_y - from.y) / dir.y
	if t <= 0:
		return
	var hit := from + dir * t
	hit.x = snapped(hit.x, 0.25)
	hit.z = snapped(hit.z, 0.25)
	hit.y = _move_origin.y
	_selected.global_position = hit


# ── Rotate ───────────────────────────────────────────────────────────────────

func _update_rotate(screen_pos: Vector2) -> void:
	if not _selected:
		return
	var delta_x := screen_pos.x - _rotate_mouse_start_x
	_selected.rotation_degrees.y = _rotate_origin_deg + delta_x * 0.5


# ── Scale ────────────────────────────────────────────────────────────────────

func _update_scale(screen_pos: Vector2) -> void:
	if not _selected:
		return
	var delta_y := _scale_mouse_start_y - screen_pos.y  # up = larger
	var factor := maxf(1.0 + delta_y * 0.005, 0.1)

	if _selected is ResizableNode3D:
		var resizable := _selected as ResizableNode3D
		resizable.size = _scale_origin_size * factor
	else:
		_selected.scale = _scale_origin_scale * factor


# ── Delete ───────────────────────────────────────────────────────────────────

func _delete_selected() -> void:
	if _selected:
		var node := _selected
		deselect()
		node.queue_free()


# ── Gizmo overlay ───────────────────────────────────────────────────────────

func _update_gizmo() -> void:
	_clear_gizmo()
	if not _selected or _active_mode == "":
		return
	_gizmo = Node3D.new()
	_gizmo.set_script(GizmoOverlayScript)
	_selected.add_child(_gizmo)
	_gizmo.set_mode(_active_mode)


func _clear_gizmo() -> void:
	if _gizmo and is_instance_valid(_gizmo):
		if _gizmo.get_parent():
			_gizmo.get_parent().remove_child(_gizmo)
		_gizmo.queue_free()
	_gizmo = null


# ── Visual highlight (translucent bounding box) ─────────────────────────────

func _add_highlight(node: Node3D) -> void:
	_clear_highlight()

	var aabb := _get_combined_aabb(node)
	if aabb.size.length() < 0.001:
		return

	var box_mesh := BoxMesh.new()
	box_mesh.size = aabb.size + Vector3(0.08, 0.08, 0.08)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.7, 1.0, 0.12)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	box_mesh.material = mat

	_highlight_box = MeshInstance3D.new()
	_highlight_box.mesh = box_mesh
	_highlight_box.position = aabb.get_center()
	node.add_child(_highlight_box)


func _clear_highlight() -> void:
	if _highlight_box and is_instance_valid(_highlight_box):
		if _highlight_box.get_parent():
			_highlight_box.get_parent().remove_child(_highlight_box)
		_highlight_box.queue_free()
	_highlight_box = null


func _get_combined_aabb(node: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(node, meshes)

	if meshes.is_empty():
		return AABB()

	var inv := node.global_transform.inverse()
	var first_mesh := meshes[0]
	var result := inv * (first_mesh.global_transform * first_mesh.get_aabb())

	for i in range(1, meshes.size()):
		var mi := meshes[i]
		var world_aabb := mi.global_transform * mi.get_aabb()
		result = result.merge(inv * world_aabb)

	return result


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, out)
