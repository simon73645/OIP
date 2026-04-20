extends Node
## In-game object selection with action-wheel-driven manipulation modes.
##
## Left-click selects objects.  After selection an action wheel offers
## Move / Rotate / Scale.  Right-click (tap, no drag) on a selected object
## reopens the wheel.  Only the gizmo for the chosen mode is displayed.
## Delete is available via the toolbar button or Del/Backspace key.
## Keyboard shortcuts: G = grab/move (click to confirm), R = rotate 90°,
## Q/E = raise/lower, Del/Backspace = delete, Esc = cancel/deselect.
## Resizable conveyors show 3D arrow handles for in-game dimension editing.

signal selection_changed(selected_node: Node3D)
signal action_wheel_requested(screen_pos: Vector2)

const RotationGizmoScript := preload("res://game/systems/rotation_gizmo.gd")
const ResizeGizmoScript := preload("res://game/systems/resize_gizmo.gd")
const MoveGizmoScript := preload("res://game/systems/move_gizmo.gd")

var _camera: Camera3D = null
var _simulation_root: Node3D = null

var _selected: Node3D = null
var _highlight_box: MeshInstance3D = null

## Toolbar mode — "select" or "delete".  Move / Rotate / Scale are handled
## exclusively via the action wheel and [member _active_mode].
var _mode: String = "select"

## Active manipulation mode chosen from the action wheel.
var _active_mode: String = ""

## Rotation gizmo shown when action-wheel "rotate" mode is active.
var _gizmo: Node3D = null

## Move gizmo shown when action-wheel "move" mode is active.
var _move_gizmo: Node3D = null

## Resize gizmo shown when a resizable conveyor is selected.
var _resize_gizmo: Node3D = null

# ── Move state ───────────────────────────────────────────────────────────────
var _moving: bool = false
## True when the current move was initiated by holding the mouse button (drag).
## False when initiated via the G keyboard shortcut (click-to-confirm).
var _drag_moving: bool = false
var _move_origin: Vector3 = Vector3.ZERO
var _floor_y: float = 0.0

# ── Rotate state (action wheel "rotate" mode: smooth mouse-X rotation) ──────
var _rotating: bool = false
var _rotate_origin_deg: float = 0.0
var _rotate_mouse_start_x: float = 0.0

# ── Scale state (action wheel "scale" mode) ─────────────────────────────────
var _scaling: bool = false
var _scale_origin_size: Vector3 = Vector3.ONE
var _scale_origin_scale: Vector3 = Vector3.ONE
var _scale_mouse_start_y: float = 0.0

## Right-click tracking for action wheel.
var _right_pressed: bool = false
var _right_press_pos: Vector2 = Vector2.ZERO

## Height step used by Q / E keys (metres, snapped to grid).
const HEIGHT_STEP: float = 0.25

## Rotation sensitivity: degrees rotated per pixel of mouse-X movement.
const ROTATE_SENSITIVITY: float = 0.5

# Deferred raycast: store click position so the raycast runs in
# _physics_process where direct_space_state is guaranteed to be valid
# (required when physics runs on a separate thread).
var _pending_select: bool = false
var _pending_select_pos: Vector2 = Vector2.ZERO
var _pending_right_click: bool = false
var _pending_right_click_pos: Vector2 = Vector2.ZERO


func setup(camera: Camera3D, simulation_root: Node3D) -> void:
	_camera = camera
	_simulation_root = simulation_root
	_setup_gizmo()
	_setup_move_gizmo()
	_setup_resize_gizmo()


func _setup_gizmo() -> void:
	_gizmo = Node3D.new()
	_gizmo.set_script(RotationGizmoScript)
	add_child(_gizmo)
	_gizmo.setup(_camera)


func _setup_move_gizmo() -> void:
	_move_gizmo = Node3D.new()
	_move_gizmo.set_script(MoveGizmoScript)
	add_child(_move_gizmo)
	_move_gizmo.setup(_camera)


func _setup_resize_gizmo() -> void:
	_resize_gizmo = Node3D.new()
	_resize_gizmo.set_script(ResizeGizmoScript)
	add_child(_resize_gizmo)
	_resize_gizmo.setup(_camera)


func get_selected() -> Node3D:
	return _selected


func select(node: Node3D) -> void:
	_clear_highlight()
	_cancel_active_interaction()
	_active_mode = ""
	_selected = node
	if _selected:
		_add_highlight(_selected)
	selection_changed.emit(_selected)
	_update_gizmo()
	_update_move_gizmo()


func deselect() -> void:
	select(null)


func is_moving() -> bool:
	return _moving


func set_mode(mode: String) -> void:
	_mode = mode
	_cancel_active_interaction()
	_active_mode = ""
	_update_gizmo()
	_update_move_gizmo()


## Called after the action wheel selects a mode.  Shows the gizmo overlay but
## does **not** auto-start the interaction — the user clicks again to interact.
## For "snap" mode, the next click on a target conveyor performs the snap.
func set_active_mode(mode: String) -> void:
	_cancel_active_interaction()
	_active_mode = mode
	_update_gizmo()
	_update_move_gizmo()


func _update_gizmo() -> void:
	if not _gizmo:
		return
	if _selected and is_instance_valid(_selected) and _active_mode == "rotate":
		_gizmo.show_for(_selected)
	else:
		_gizmo.hide_gizmo()
	_update_resize_gizmo()


func _update_resize_gizmo() -> void:
	if not _resize_gizmo:
		return
	# Only show resize arrows when no action mode is active or when explicitly
	# in scale mode.  Hide them in move and rotate modes.
	var mode_allows := _active_mode == "" or _active_mode == "scale"
	if _selected and is_instance_valid(_selected) and _is_resizable(_selected) and mode_allows:
		_resize_gizmo.show_for(_selected)
	else:
		_resize_gizmo.hide_gizmo()


## Returns true if the node is a resizable conveyor (straight or curved).
func _is_resizable(node: Node3D) -> bool:
	if node is ResizableNode3D:
		return true
	if node is CurvedBeltConveyorAssembly or node is CurvedRollerConveyorAssembly:
		return true
	return false


# ── Gizmo overlay (action wheel feedback) ────────────────────────────────────

func _update_move_gizmo() -> void:
	if not _move_gizmo:
		return
	if _selected and is_instance_valid(_selected) and _active_mode == "move":
		_move_gizmo.show_for(_selected)
	else:
		_move_gizmo.hide_gizmo()


# ── Interaction cancellation ──────────────────────────────────────────────────

func _cancel_active_interaction() -> void:
	if _moving and _selected and is_instance_valid(_selected):
		_selected.global_position = _move_origin
	_moving = false
	_drag_moving = false
	if _rotating and _selected and is_instance_valid(_selected):
		_selected.rotation_degrees.y = _rotate_origin_deg
	_rotating = false
	if _scaling and _selected and is_instance_valid(_selected):
		if _selected is ResizableNode3D:
			(_selected as ResizableNode3D).size = _scale_origin_size
		else:
			_selected.scale = _scale_origin_scale
	_scaling = false


# ── Input ────────────────────────────────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	if _pending_select:
		_pending_select = false
		_do_pending_action(_pending_select_pos)
	if _pending_right_click:
		_pending_right_click = false
		_handle_right_click(_pending_right_click_pos)


func _unhandled_input(event: InputEvent) -> void:
	# Don't process selection/move when a gizmo is being dragged.
	if _resize_gizmo and _resize_gizmo.is_dragging():
		return
	if _move_gizmo and _move_gizmo.is_dragging():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# ── Left button ──────────────────────────────────────────────
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Confirm an in-progress interaction.
				if _moving and not _drag_moving:
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
			else:
				# Mouse button released — confirm drag-initiated move.
				if _moving and _drag_moving:
					_moving = false
					_drag_moving = false
					get_viewport().set_input_as_handled()

		# ── Right button (action wheel) ─────────────────────────────
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
		if key.pressed and not key.echo and _selected:
			match key.keycode:
				KEY_DELETE, KEY_BACKSPACE:
					_delete_selected()
					get_viewport().set_input_as_handled()
				KEY_G:
					if not _moving:
						_moving = true
						_drag_moving = false
						_move_origin = _selected.global_position
					get_viewport().set_input_as_handled()
				KEY_R:
					_selected.rotation_degrees.y = fmod(_selected.rotation_degrees.y + 90.0, 360.0)
					get_viewport().set_input_as_handled()
				KEY_Q:
					_selected.global_position.y += HEIGHT_STEP
					get_viewport().set_input_as_handled()
				KEY_E:
					_selected.global_position.y -= HEIGHT_STEP
					get_viewport().set_input_as_handled()
				KEY_ESCAPE:
					if _moving or _rotating or _scaling:
						_cancel_active_interaction()
					else:
						deselect()
					get_viewport().set_input_as_handled()


## Handles a deferred left-click based on the current toolbar mode.
func _do_pending_action(screen_pos: Vector2) -> void:
	var hit := _raycast_hit(screen_pos)

	# Delete mode (toolbar).
	if _mode == "delete":
		if hit:
			select(hit)
			_delete_selected()
		else:
			deselect()
		return

	# Snap mode: click picks the target conveyor and performs the snap.
	if _active_mode == "snap" and _selected and is_instance_valid(_selected):
		if hit and hit != _selected:
			var success := ConveyorSnapping.snap_to_target(_selected, hit)
			if success:
				# Re-apply highlight to reflect the new position.
				_clear_highlight()
				_add_highlight(_selected)
			_active_mode = ""
			_update_gizmo()
			_update_move_gizmo()
		elif hit == null:
			# Clicking on empty space cancels snap mode.
			_active_mode = ""
			_update_gizmo()
			_update_move_gizmo()
		# If hit == _selected, re-open the action wheel.
		else:
			action_wheel_requested.emit(screen_pos)
		return

	# Select mode (default): action-wheel-driven flow.
	if hit == null:
		deselect()
		return

	if hit == _selected:
		if _active_mode != "":
			# Re-enter the current interaction.
			_start_active_mode_interaction()
		else:
			# Show the action wheel for mode choice.
			action_wheel_requested.emit(screen_pos)
	else:
		# New object — select and show wheel.
		select(hit)
		action_wheel_requested.emit(screen_pos)


func _start_active_mode_interaction() -> void:
	match _active_mode:
		"move":
			if not _moving:
				_moving = true
				_drag_moving = false
				_move_origin = _selected.global_position
		"rotate":
			pass  # The rotation_gizmo handles its own input via _input().
		"scale":
			# Only use the drag-scale interaction for non-resizable objects.
			# Resizable objects are handled by the resize_gizmo arrows.
			if not _scaling and not _is_resizable(_selected):
				_scaling = true
				_scale_origin_scale = _selected.scale
				_scale_mouse_start_y = get_viewport().get_mouse_position().y


## Handles a deferred right-click: only opens the action wheel if the tap
## landed on the already-selected object.
func _handle_right_click(screen_pos: Vector2) -> void:
	var hit := _raycast_hit(screen_pos)
	if hit and hit == _selected:
		_cancel_active_interaction()
		_active_mode = ""
		_update_move_gizmo()
		action_wheel_requested.emit(screen_pos)


# ── Raycast helper ───────────────────────────────────────────────────────────

func _raycast_hit(screen_pos: Vector2) -> Node3D:
	if not _camera:
		return null
	var from := _camera.project_ray_origin(screen_pos)
	var to := from + _camera.project_ray_normal(screen_pos) * 500.0
	var space := _camera.get_world_3d().direct_space_state
	if not space:
		return null
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	var result := space.intersect_ray(query)
	if result.is_empty():
		return null
	var collider := result["collider"] as Node
	if collider:
		return _find_simulation_child(collider)
	return null


func _find_simulation_child(node: Node) -> Node3D:
	if not _simulation_root:
		return null
	var current := node
	while current:
		if current.get_parent() == _simulation_root:
			return current as Node3D
		current = current.get_parent()
	return null


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


func _update_rotate(screen_pos: Vector2) -> void:
	if not _selected:
		return
	var delta_x := screen_pos.x - _rotate_mouse_start_x
	_selected.rotation_degrees.y = _rotate_origin_deg + delta_x * ROTATE_SENSITIVITY


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


func _delete_selected() -> void:
	if _selected:
		var node := _selected
		deselect()
		node.queue_free()


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
	# Centre the box on the AABB, expressed in the node's local space.
	_highlight_box.position = aabb.get_center()
	node.add_child(_highlight_box)


func _clear_highlight() -> void:
	if _highlight_box and is_instance_valid(_highlight_box):
		# Remove from parent immediately so _collect_meshes won't include the
		# stale highlight when recomputing the AABB on the next selection.
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
