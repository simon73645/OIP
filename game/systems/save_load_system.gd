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
var _sensor_bridge: Node = null  # Optional PlcSensorBridge for sensor address overrides

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


## Optional: provide a reference to the PLC sensor bridge so that sensor and
## diverter address overrides configured via the in-game UI are persisted
## across save/load cycles.
func set_sensor_bridge(bridge: Node) -> void:
	_sensor_bridge = bridge


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
		# etc.) so that custom dimensions persist.
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

	# Reset the PLC sensor bridge so stale registrations from the previous
	# simulation don't conflict with the freshly loaded sensors/diverters.
	if _sensor_bridge:
		if _sensor_bridge.has_method("unregister_all"):
			_sensor_bridge.unregister_all()
		# Drop stale instance-id keyed overrides from the previous simulation.
		if _sensor_bridge.has_method("clear_address_overrides"):
			_sensor_bridge.clear_address_overrides()

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

		# Pre-set the size BEFORE adding to the tree so that the assembly's
		# _ready uses the saved size when propagating to its inner conveyor
		# (otherwise side guards / frame rails would first be generated at
		# the default size and then resized).
		if instance is ResizableNode3D and obj_data.has("size"):
			instance.size = _array_to_vec3(obj_data["size"])

		# Pre-set side-guard and frame-rail state on internal nodes BEFORE
		# adding to the tree.  This way the very first call to
		# _update_side_guards / _restore_frame_rail_state during _ready will
		# pick up the saved layout instead of generating default full-length
		# guards.  This is what restores the gaps created by snapping.
		if obj_data.has("attributes"):
			_pre_deserialize_attributes(instance, obj_data["attributes"])

		_simulation_root.add_child(instance)

		instance.global_position = _array_to_vec3(obj_data.get("position", [0, 0, 0]))
		instance.rotation_degrees = _array_to_vec3(obj_data.get("rotation", [0, 0, 0]))
		instance.scale = _array_to_vec3(obj_data.get("scale", [1, 1, 1]))

		# Restore extra attributes (e.g. color for Box nodes, sensor PLC
		# address overrides, BoxSpawner spawn rate, etc.).
		if obj_data.has("attributes"):
			_deserialize_attributes(instance, obj_data["attributes"])

		# Store the scene path for future saves.
		instance.set_meta("_scene_path", scene_path)

	# Re-register sensors and diverters with the PLC bridge so the freshly
	# loaded objects appear in the PLC data items (and use any restored
	# address overrides).  No-op when the PLC is not connected.
	if _sensor_bridge and _sensor_bridge.has_method("register_sensors"):
		_sensor_bridge.register_sensors()

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


## Serialize extra attributes for the given node. Returns a dictionary of
## attribute values that should be persisted beyond position/rotation/scale.
func _serialize_attributes(node: Node3D) -> Dictionary:
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

	# BoxSpawner – persist spawn rate, color and related options so that the
	# user's tuning is reproduced after load.
	if node is BoxSpawner:
		var spawner := node as BoxSpawner
		attrs["box_color"] = [spawner.box_color.r, spawner.box_color.g,
				spawner.box_color.b, spawner.box_color.a]
		attrs["boxes_per_minute"] = spawner.boxes_per_minute
		attrs["fixed_rate"] = spawner.fixed_rate
		attrs["disable"] = spawner.disable

	# Side-guard layouts and frame-rail layouts (these are mutated during
	# snapping to create gaps where conveyors meet).  Walk the subtree to
	# collect every node that holds either a `_guard_state` or
	# `_frame_rail_state` dictionary, keyed by NodePath relative to the root.
	var snap_state: Dictionary = _collect_snap_state(node)
	if not snap_state.is_empty():
		attrs["_snap_state"] = snap_state

	# Sensor PLC address overrides — registered via the in-game sensor
	# properties panel.  Stored on the bridge keyed by instance_id, so we
	# need to persist them ourselves and re-apply on load.
	if _sensor_bridge and (node is DiffuseSensor or node is LaserSensor or node is ColorSensor):
		var override: Dictionary = _sensor_bridge.get_address_override(node.get_instance_id())
		if not override.is_empty():
			attrs["_plc_address"] = {
				"start_byte": int(override.get("start_byte", 0)),
				"bit": int(override.get("bit", 0)),
			}

	# Diverter PLC address override.
	if _sensor_bridge and node is Diverter:
		var override: Dictionary = _sensor_bridge.get_diverter_address_override(node.get_instance_id())
		if not override.is_empty():
			attrs["_plc_address"] = {
				"start_byte": int(override.get("start_byte", 0)),
				"bit": int(override.get("bit", 0)),
			}

	return attrs


## Pre-deserialize state that must be applied BEFORE the node is added to
## the scene tree (so the very first call to _ready / size_changed picks up
## the saved layout instead of regenerating defaults).  Currently this
## restores side-guard layouts and frame-rail layouts.
static func _pre_deserialize_attributes(node: Node3D, attrs: Dictionary) -> void:
	if not attrs.has("_snap_state"):
		return
	var snap_state: Dictionary = attrs["_snap_state"]
	for path_str: String in snap_state.keys():
		var entry: Dictionary = snap_state[path_str]
		var target: Node = node if path_str == "." else node.get_node_or_null(NodePath(path_str))
		if not target:
			continue
		if entry.has("guard_state") and "_guard_state" in target:
			target._guard_state = _convert_guard_state(entry["guard_state"])
		if entry.has("frame_rail_state") and "_frame_rail_state" in target:
			target._frame_rail_state = _convert_frame_rail_state(entry["frame_rail_state"])


## Restore extra attributes previously serialized by [method _serialize_attributes].
func _deserialize_attributes(node: Node3D, attrs: Dictionary) -> void:
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

	# BoxSpawner configuration.
	if node is BoxSpawner:
		var spawner := node as BoxSpawner
		if attrs.has("box_color"):
			var a: Array = attrs["box_color"]
			if a.size() >= 4:
				spawner.box_color = Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
			elif a.size() >= 3:
				spawner.box_color = Color(float(a[0]), float(a[1]), float(a[2]))
		if attrs.has("boxes_per_minute"):
			spawner.boxes_per_minute = int(attrs["boxes_per_minute"])
		if attrs.has("fixed_rate"):
			spawner.fixed_rate = bool(attrs["fixed_rate"])
		if attrs.has("disable"):
			spawner.disable = bool(attrs["disable"])

	# Sensor / Diverter PLC address override.
	if attrs.has("_plc_address") and _sensor_bridge:
		var addr: Dictionary = attrs["_plc_address"]
		var start_byte: int = int(addr.get("start_byte", 0))
		var bit: int = int(addr.get("bit", 0))
		if node is DiffuseSensor or node is LaserSensor or node is ColorSensor:
			_sensor_bridge.set_sensor_address(node, start_byte, bit)
		elif node is Diverter:
			_sensor_bridge.set_diverter_address(node, start_byte, bit)


## Walk [param node] (and its descendants) collecting any node that holds a
## `_guard_state` (SideGuardsAssembly) or `_frame_rail_state` dictionary.
## Returns a dictionary keyed by NodePath-relative-to-root.
static func _collect_snap_state(node: Node3D) -> Dictionary:
	var result: Dictionary = {}
	_collect_snap_state_recursive(node, node, result)
	return result


static func _collect_snap_state_recursive(root: Node, current: Node, result: Dictionary) -> void:
	var has_guard: bool = "_guard_state" in current and (current._guard_state as Dictionary).size() > 0
	var has_rails: bool = "_frame_rail_state" in current and (current._frame_rail_state as Dictionary).size() > 0
	if has_guard or has_rails:
		var path_str: String = "." if current == root else str(root.get_path_to(current))
		var entry: Dictionary = {}
		if has_guard:
			entry["guard_state"] = (current._guard_state as Dictionary).duplicate(true)
		if has_rails:
			entry["frame_rail_state"] = (current._frame_rail_state as Dictionary).duplicate(true)
		result[path_str] = entry
	for child in current.get_children():
		_collect_snap_state_recursive(root, child, result)


## JSON only stores numbers as floats and dictionary values as Variants, so
## convert the persisted guard-state entries back to the exact types the
## SideGuardsAssembly expects.
static func _convert_guard_state(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in raw.keys():
		var v: Dictionary = raw[key]
		out[str(key)] = {
			"pos_x": float(v.get("pos_x", 0.0)),
			"length": float(v.get("length", 0.01)),
			"front_anchored": bool(v.get("front_anchored", true)),
			"back_anchored": bool(v.get("back_anchored", true)),
			"front_boundary_tracking": bool(v.get("front_boundary_tracking", false)),
			"back_boundary_tracking": bool(v.get("back_boundary_tracking", false)),
		}
	return out


static func _convert_frame_rail_state(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in raw.keys():
		var v: Dictionary = raw[key]
		out[str(key)] = {
			"pos_x": float(v.get("pos_x", 0.0)),
			"length": float(v.get("length", 0.01)),
			"front_anchored": bool(v.get("front_anchored", true)),
			"back_anchored": bool(v.get("back_anchored", true)),
			"front_boundary_tracking": bool(v.get("front_boundary_tracking", false)),
			"back_boundary_tracking": bool(v.get("back_boundary_tracking", false)),
		}
	return out


## Locate the inner belt/curved-belt conveyor child used by assemblies.
static func _find_inner_conveyor(node: Node3D) -> Node:
	var child := node.get_node_or_null("Conveyor")
	if child and (child is BeltConveyor or child is CurvedBeltConveyor):
		return child
	child = node.get_node_or_null("ConveyorCorner")
	if child and (child is BeltConveyor or child is CurvedBeltConveyor):
		return child
	return null
