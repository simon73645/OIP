extends Node
## Save/Load system for the simulation.
##
## Serializes all direct children of the simulation root into a JSON file.
## Each object is stored with its scene path, position, rotation, and scale.
## Loading clears the current simulation and recreates objects from the file.

signal simulation_saved(path: String)
signal simulation_loaded(path: String)
signal save_failed(reason: String)
signal load_failed(reason: String)

var _simulation_root: Node3D = null

## List of known scene paths for each class name so we can reverse-lookup
## scene paths for objects that were placed before the save system was added.
const CLASS_SCENE_MAP: Dictionary = {
	"BeltConveyorAssembly": "res://parts/assemblies/BeltConveyorAssembly.tscn",
	"BeltSpurConveyorAssembly": "res://parts/assemblies/BeltSpurConveyorAssembly.tscn",
	"CurvedBeltConveyorAssembly": "res://parts/assemblies/CurvedBeltConveyorAssembly.tscn",
	"RollerConveyorAssembly": "res://parts/assemblies/RollerConveyorAssembly.tscn",
	"CurvedRollerConveyorAssembly": "res://parts/assemblies/CurvedRollerConveyorAssembly.tscn",
	"RollerSpurConveyorAssembly": "res://parts/assemblies/RollerSpurConveyorAssembly.tscn",
	"BoxSpawner": "res://parts/BoxSpawner.tscn",
	"PalletSpawner": "res://parts/PalletSpawner.tscn",
	"Despawner": "res://parts/Despawner.tscn",
	"DiffuseSensor": "res://parts/DiffuseSensor.tscn",
	"LaserSensor": "res://parts/LaserSensor.tscn",
	"ColorSensor": "res://parts/ColorSensor.tscn",
	"Diverter": "res://parts/Diverter.tscn",
	"ChainTransfer": "res://parts/ChainTransfer.tscn",
	"BladeStop": "res://parts/BladeStop.tscn",
	"StackLight": "res://parts/StackLight.tscn",
	"PushButton": "res://parts/PushButton.tscn",
	"Box": "res://parts/Box.tscn",
	"Pallet": "res://parts/Pallet.tscn",
}


func setup(simulation_root: Node3D) -> void:
	_simulation_root = simulation_root


## Save the current simulation to a JSON file.
func save_simulation(file_path: String) -> void:
	if not _simulation_root:
		save_failed.emit("No simulation root set.")
		return

	var objects: Array[Dictionary] = []

	for child: Node in _simulation_root.get_children():
		if not child is Node3D:
			continue
		var node := child as Node3D

		var scene_path: String = ""

		# Try to get the scene path from metadata (set during placement).
		if node.has_meta("_scene_path"):
			scene_path = node.get_meta("_scene_path")

		# Fall back to scene_file_path (PackedScene resource path).
		if scene_path.is_empty() and not node.scene_file_path.is_empty():
			scene_path = node.scene_file_path

		# Fall back to class name lookup.
		if scene_path.is_empty():
			var class_name_str := _get_class_name(node)
			if CLASS_SCENE_MAP.has(class_name_str):
				scene_path = CLASS_SCENE_MAP[class_name_str]

		if scene_path.is_empty():
			# Skip objects without an identifiable scene path (e.g. spawned
			# boxes/pallets that are transient runtime objects and should not
			# persist across save/load cycles).
			continue

		var entry: Dictionary = {
			"scene_path": scene_path,
			"position": _vec3_to_array(node.global_position),
			"rotation": _vec3_to_array(node.rotation_degrees),
			"scale": _vec3_to_array(node.scale),
		}

		# Save the size property for ResizableNode3D nodes (conveyors, boxes,
		# etc.) so that scaling done via the resize gizmo persists.
		if node is ResizableNode3D:
			entry["size"] = _vec3_to_array(node.size)

		# Save extra attributes that are needed to fully restore the object.
		entry["attributes"] = _serialize_attributes(node)

		objects.append(entry)

	var save_data: Dictionary = {
		"version": 1,
		"objects": objects,
	}

	var json_string := JSON.stringify(save_data, "  ")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		save_failed.emit("Could not open file for writing: %s" % file_path)
		return

	file.store_string(json_string)
	file.close()
	simulation_saved.emit(file_path)


## Load a simulation from a JSON file, replacing all current objects.
func load_simulation(file_path: String) -> void:
	if not _simulation_root:
		load_failed.emit("No simulation root set.")
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		load_failed.emit("Could not open file: %s" % file_path)
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		load_failed.emit("JSON parse error: %s" % json.get_error_message())
		return

	var save_data: Dictionary = json.data
	if not save_data.has("objects"):
		load_failed.emit("Invalid save file: missing 'objects' key.")
		return

	# Clear existing simulation objects.
	_clear_simulation()

	# Wait one frame for queue_free to complete, ensuring all freed nodes
	# are fully removed before instantiating new ones to avoid name
	# conflicts or stale references.
	await get_tree().process_frame

	# Recreate objects.
	var objects: Array = save_data["objects"]
	for obj_data: Dictionary in objects:
		var scene_path: String = obj_data.get("scene_path", "")
		if scene_path.is_empty():
			continue

		var scene := load(scene_path) as PackedScene
		if not scene:
			push_warning("SaveLoadSystem: Could not load scene: %s" % scene_path)
			continue

		var instance := scene.instantiate()
		_simulation_root.add_child(instance)

		instance.global_position = _array_to_vec3(obj_data.get("position", [0, 0, 0]))
		instance.rotation_degrees = _array_to_vec3(obj_data.get("rotation", [0, 0, 0]))
		instance.scale = _array_to_vec3(obj_data.get("scale", [1, 1, 1]))

		# Restore the size property for ResizableNode3D nodes so that
		# scaling done via the resize gizmo is preserved.
		if instance is ResizableNode3D and obj_data.has("size"):
			instance.size = _array_to_vec3(obj_data["size"])

		# Restore extra attributes (e.g. color for Box nodes).
		if obj_data.has("attributes"):
			_deserialize_attributes(instance, obj_data["attributes"])

		# Store the scene path for future saves.
		instance.set_meta("_scene_path", scene_path)

	simulation_loaded.emit(file_path)


## Clear all objects in the simulation root.
func _clear_simulation() -> void:
	for child: Node in _simulation_root.get_children():
		child.queue_free()


## Get the class name string for a node.
func _get_class_name(node: Node) -> String:
	var script := node.get_script() as Script
	if script:
		# Try to get the class_name from the script.
		var gn := script.get_global_name()
		if not gn.is_empty():
			return gn
	return node.get_class()


# ── Serialization helpers ────────────────────────────────────────────────────

static func _vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _array_to_vec3(a: Array) -> Vector3:
	if a.size() < 3:
		return Vector3.ZERO
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Serialize extra attributes for the given node.  Returns a dictionary of
## attribute values that should be persisted beyond position/rotation/scale.
static func _serialize_attributes(node: Node3D) -> Dictionary:
	var attrs: Dictionary = {}

	# Box – persist the user-chosen color.
	if node is Box:
		var c: Color = node.color
		attrs["color"] = [c.r, c.g, c.b, c.a]

	# BeltConveyor / CurvedBeltConveyor – persist speed and direction.
	if node is BeltConveyor:
		attrs["speed"] = node.speed
		attrs["reverse_belt"] = node.reverse_belt
	elif node is CurvedBeltConveyor:
		attrs["speed"] = node.speed
		attrs["reverse_belt"] = node.reverse_belt

	# Assemblies – check for inner conveyor and save its properties too.
	var inner_conveyor := _find_inner_conveyor(node)
	if inner_conveyor:
		var conv_attrs: Dictionary = {}
		conv_attrs["speed"] = inner_conveyor.speed
		conv_attrs["reverse_belt"] = inner_conveyor.reverse_belt
		attrs["_conveyor"] = conv_attrs

	return attrs


## Restore extra attributes previously serialized by [method _serialize_attributes].
static func _deserialize_attributes(node: Node3D, attrs: Dictionary) -> void:
	# Box color.
	if node is Box and attrs.has("color"):
		var a: Array = attrs["color"]
		if a.size() >= 4:
			node.color = Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
		elif a.size() >= 3:
			node.color = Color(float(a[0]), float(a[1]), float(a[2]))

	# Direct conveyor properties.
	if node is BeltConveyor or node is CurvedBeltConveyor:
		if attrs.has("speed"):
			node.speed = float(attrs["speed"])
		if attrs.has("reverse_belt"):
			node.reverse_belt = bool(attrs["reverse_belt"])

	# Inner conveyor inside an assembly.
	if attrs.has("_conveyor"):
		var inner_conveyor := _find_inner_conveyor(node)
		if inner_conveyor:
			var conv_attrs: Dictionary = attrs["_conveyor"]
			if conv_attrs.has("speed"):
				inner_conveyor.speed = float(conv_attrs["speed"])
			if conv_attrs.has("reverse_belt"):
				inner_conveyor.reverse_belt = bool(conv_attrs["reverse_belt"])


## Locate the inner belt/curved-belt conveyor child used by assemblies.
static func _find_inner_conveyor(node: Node3D) -> Node:
	var child := node.get_node_or_null("Conveyor")
	if child and (child is BeltConveyor or child is CurvedBeltConveyor):
		return child
	child = node.get_node_or_null("ConveyorCorner")
	if child and (child is BeltConveyor or child is CurvedBeltConveyor):
		return child
	return null
