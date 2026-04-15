extends Node3D
## Handles placing equipment into the simulation.
##
## When activated with a scene path, it shows a semi-transparent preview that
## follows the mouse cursor on the floor plane.  Left-click places the object,
## right-click / Escape cancels, R rotates 90 degrees.

signal object_placed(instance: Node3D)
signal placement_cancelled

var _active: bool = false
var _scene_path: String = ""
var _preview: Node3D = null
var _rotation_y: float = 0.0
var _camera: Camera3D = null
var _simulation_root: Node3D = null
var _floor_y: float = 0.0
var _placement_elevation: float = 0.0


func setup(camera: Camera3D, simulation_root: Node3D) -> void:
	_camera = camera
	_simulation_root = simulation_root


func activate(scene_path: String) -> void:
	# Quietly clear any existing preview (without emitting cancelled signal).
	_clear_preview()
	_scene_path = scene_path
	_rotation_y = 0.0
	_active = true

	var scene := load(scene_path) as PackedScene
	if not scene:
		_active = false
		return

	var instance := scene.instantiate()
	if not instance is Node3D:
		# Scene root is not a 3D node (e.g. GenericData) — cannot be placed.
		instance.queue_free()
		_active = false
		return

	_preview = instance as Node3D
	add_child(_preview)
	_placement_elevation = _get_legs_elevation(_preview)
	# Flag the preview so scripts (e.g. Box) that defer physics activation
	# can skip it.  Must be set before _make_preview because the deferred
	# call from _ready() will run after the current frame.
	_preview.set_meta("_is_preview", true)
	# Run _make_preview AFTER add_child so it overrides any physics state
	# that _ready() may have set (e.g. Box unfreezing when simulation runs).
	_make_preview(_preview)
	# Re-enable processing on the ConveyorLegsAssembly so that the preview
	# shows properly positioned legs instead of default/invisible ones.
	var legs := _find_legs_assembly(_preview)
	if legs:
		legs.set_physics_process(true)


func deactivate() -> void:
	var was_active := _active
	_clear_preview()
	_active = false
	_scene_path = ""
	if was_active:
		placement_cancelled.emit()


## Stop placing without emitting the cancelled signal (e.g. when switching
## toolbar modes).
func cancel_silently() -> void:
	_clear_preview()
	_active = false
	_scene_path = ""


func _clear_preview() -> void:
	if _preview:
		_preview.queue_free()
		_preview = null


func is_active() -> bool:
	return _active


# ── Input handling ───────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_LEFT:
					_place_object()
					get_viewport().set_input_as_handled()
				MOUSE_BUTTON_RIGHT:
					deactivate()
					get_viewport().set_input_as_handled()

	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_R:
				_rotation_y = fmod(_rotation_y + 90.0, 360.0)
				if _preview:
					_preview.rotation_degrees.y = _rotation_y
				get_viewport().set_input_as_handled()
			elif key.keycode == KEY_ESCAPE:
				deactivate()
				get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _active and _preview:
		_update_preview_position(get_viewport().get_mouse_position())


# ── Internals ────────────────────────────────────────────────────────────────

func _update_preview_position(screen_pos: Vector2) -> void:
	if not _camera or not _preview:
		return

	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)

	# Intersect with horizontal floor plane.
	if abs(dir.y) < 0.001:
		return

	var t := (_floor_y - from.y) / dir.y
	if t <= 0:
		return

	var hit := from + dir * t
	# Snap to 0.25 m grid.
	hit.x = snapped(hit.x, 0.25)
	hit.z = snapped(hit.z, 0.25)
	hit.y = _floor_y + _placement_elevation
	_preview.global_position = hit


func _place_object() -> void:
	if not _preview or _scene_path.is_empty():
		return

	var scene := load(_scene_path) as PackedScene
	if not scene:
		return

	var target_position := _preview.global_position
	var instance := scene.instantiate()
	# Add to the tree BEFORE setting global_position, which requires the node
	# to be inside the scene tree.
	_simulation_root.add_child(instance)
	# NOTE: Do NOT set instance.owner = _simulation_root here.
	# Assembly scenes (e.g. BeltConveyorAssembly) rely on unique-name (%Node)
	# references that are scoped to the scene root's owner.  Changing the
	# owner after _ready() has run would break those references and prevent
	# the assembly from forwarding size / leg / side-guard changes to its
	# children.
	instance.global_position = target_position
	instance.rotation_degrees.y = _rotation_y

	object_placed.emit(instance)

	# Deactivate after placing a single object (no repeated placement).
	# Don't call deactivate() to avoid emitting placement_cancelled.
	_clear_preview()
	_active = false
	_scene_path = ""


## Make all meshes transparent and disable physics so the preview doesn't
## interfere with the simulation.
func _make_preview(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).transparency = 0.6
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	if node is RigidBody3D:
		var rb := node as RigidBody3D
		rb.freeze = true
		rb.top_level = false
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
	if node is PhysicsBody3D:
		var body := node as PhysicsBody3D
		body.collision_layer = 0
		body.collision_mask = 0
	if node is AnimatableBody3D:
		(node as AnimatableBody3D).collision_layer = 0
		(node as AnimatableBody3D).collision_mask = 0

	# Disable processing so simulation scripts (Box, Pallet, Spawners, etc.)
	# don't run their logic on the preview instance.
	node.set_process(false)
	node.set_physics_process(false)

	for child in node.get_children():
		_make_preview(child)


## Calculate the Y elevation needed so that conveyor legs reach the floor.
## Assemblies with a ConveyorLegsAssembly child have legs that extend downward
## from the conveyor to a floor plane.  The legs node is offset below the
## assembly root (typically y = -2).  We negate that offset so the assembly is
## placed high enough for the legs to sit on the floor.
func _get_legs_elevation(node: Node3D) -> float:
	var legs := _find_legs_assembly(node)
	if legs == null:
		return 0.0
	# Walk from the legs node up to the root and accumulate the Y offset.
	var y_offset := 0.0
	var current: Node = legs
	while current != null and current != node:
		if current is Node3D:
			y_offset += (current as Node3D).position.y
		current = current.get_parent()
	return -y_offset


## Recursively search for a ConveyorLegsAssembly (or CurvedConveyorLegsAssembly)
## node in the subtree rooted at [param node].
static func _find_legs_assembly(node: Node) -> Node:
	if node is ConveyorLegsAssembly:
		return node
	for child in node.get_children():
		var found := _find_legs_assembly(child)
		if found != null:
			return found
	return null
