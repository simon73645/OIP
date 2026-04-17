extends Node
## Bridges simulation sensors to the Siemens PLC via the siemens_plugin's
## GroupData / DataItem system.
##
## When the PLC connects (and goes online), this bridge:
##   1. Scans _simulation_root for Color-, Diffuse- and LaserSensor nodes.
##   2. For each sensor that has `enable_comms == false` (i.e. not already
##      using the OIP comms layer), it creates a matching C# DataItem
##      (BoolItem / RealItem / DIntItem) under a GroupData child of the Plc
##      node and binds the sensor's visual property.
##
## This lets the PLC read sensor outputs and (optionally) write actuator
## commands back, without requiring the user to manually add DataItems in
## the editor.
##
## Usage:
##   var bridge = PlcSensorBridge.new()
##   bridge.setup(simulation_root_node)
##   add_child(bridge)

## Emitted whenever a sensor is registered or unregistered, so that UI can
## update its display of connected sensors.
signal sensors_changed

var _simulation_root: Node3D = null
var _group_data: Node = null  # GroupData C# node
var _registered_sensors: Array[Node3D] = []

## Tracks the next free byte address in the Memory area so that each sensor
## gets a unique, non-overlapping address.
var _next_byte_address: int = 0

## Per-sensor address overrides: sensor instance_id → { "start_byte": int, "bit": int }
## When the user configures a custom address via the sensor UI, the override
## is stored here and will be applied on next (re-)registration.
var _address_overrides: Dictionary = {}


func setup(simulation_root: Node3D) -> void:
	_simulation_root = simulation_root


func _ready() -> void:
	# React to connection changes.
	PlcConnectionManager.connection_state_changed.connect(_on_connection_changed)


## Scans the simulation root for sensors and registers them with the PLC.
func register_sensors() -> void:
	if not _simulation_root:
		return

	var plc_node := PlcConnectionManager.get_plc_node()
	if not plc_node:
		return

	# Ensure we have a GroupData node.
	_ensure_group_data(plc_node)
	if not _group_data:
		return

	# Find all sensors.
	var sensors: Array[Node] = []
	_find_sensors(_simulation_root, sensors)

	for sensor: Node in sensors:
		if sensor in _registered_sensors:
			continue
		_register_sensor(sensor)

	sensors_changed.emit()


## Removes all registered items (e.g. on disconnect).
func unregister_all() -> void:
	if _group_data and is_instance_valid(_group_data):
		for child: Node in _group_data.get_children():
			child.queue_free()
	_registered_sensors.clear()
	_next_byte_address = 0
	sensors_changed.emit()


## Returns an array of dictionaries describing each registered sensor:
## [{ "sensor": Node3D, "type": String, "data_type": String,
##    "start_byte": int, "bit": int }]
func get_registered_sensor_info() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sensor: Node3D in _registered_sensors:
		var info: Dictionary = _get_sensor_info(sensor)
		result.append(info)
	return result


## Sets a custom PLC address for a sensor.  Takes effect on the next
## register_sensors() call or immediately if the sensor is already
## registered (re-registers it).
func set_sensor_address(sensor: Node3D, start_byte: int, bit: int = 0) -> void:
	_address_overrides[sensor.get_instance_id()] = {
		"start_byte": start_byte,
		"bit": bit,
	}
	# If already registered, re-register with new address.
	if sensor in _registered_sensors:
		_unregister_sensor(sensor)
		_register_sensor(sensor)
		sensors_changed.emit()


## Returns the PLC address info for a specific sensor, or an empty dict if
## the sensor is not registered.
func get_sensor_address(sensor: Node3D) -> Dictionary:
	if sensor not in _registered_sensors:
		return {}
	return _get_sensor_info(sensor)


# ── Internal helpers ─────────────────────────────────────────────────────────

func _get_sensor_info(sensor: Node3D) -> Dictionary:
	var info: Dictionary = {}
	info["sensor"] = sensor
	info["name"] = sensor.name

	var override: Dictionary = _address_overrides.get(sensor.get_instance_id(), {})
	var start_byte: int = override.get("start_byte", -1)
	var bit: int = override.get("bit", 0)

	if sensor is DiffuseSensor:
		info["type"] = "DiffuseSensor"
		info["data_type"] = "BOOL"
		info["plc_type"] = "BoolItem"
		# Find actual address from the DataItem node if possible.
		var item := _find_data_item_for(sensor)
		if item:
			info["start_byte"] = item.get("StartByteAdr")
			info["bit"] = item.get("BitAdr")
			info["address"] = "M%d.%d" % [info["start_byte"], info["bit"]]
		elif start_byte >= 0:
			info["start_byte"] = start_byte
			info["bit"] = bit
			info["address"] = "M%d.%d" % [start_byte, bit]
		else:
			info["start_byte"] = 0
			info["bit"] = 0
			info["address"] = "M0.0"

	elif sensor is LaserSensor:
		info["type"] = "LaserSensor"
		info["data_type"] = "REAL"
		info["plc_type"] = "RealItem"
		var item := _find_data_item_for(sensor)
		if item:
			info["start_byte"] = item.get("StartByteAdr")
			info["bit"] = 0
			info["address"] = "MD%d" % info["start_byte"]
		elif start_byte >= 0:
			info["start_byte"] = start_byte
			info["bit"] = 0
			info["address"] = "MD%d" % start_byte
		else:
			info["start_byte"] = 4
			info["bit"] = 0
			info["address"] = "MD4"

	elif sensor is ColorSensor:
		info["type"] = "ColorSensor"
		info["data_type"] = "DINT"
		info["plc_type"] = "DIntItem"
		var item := _find_data_item_for(sensor)
		if item:
			info["start_byte"] = item.get("StartByteAdr")
			info["bit"] = 0
			info["address"] = "MD%d" % info["start_byte"]
		elif start_byte >= 0:
			info["start_byte"] = start_byte
			info["bit"] = 0
			info["address"] = "MD%d" % start_byte
		else:
			info["start_byte"] = 8
			info["bit"] = 0
			info["address"] = "MD8"

	return info


func _find_data_item_for(sensor: Node3D) -> Node:
	if not _group_data or not is_instance_valid(_group_data):
		return null
	var target_name := "Sensor_%s" % sensor.name
	for child: Node in _group_data.get_children():
		if child.name == target_name:
			return child
	return null


func _ensure_group_data(plc_node: Node) -> void:
	# Look for an existing GroupData child named "SensorBridgeGroup".
	for child: Node in plc_node.get_children():
		if child.name == "SensorBridgeGroup":
			_group_data = child
			return

	# Create a new GroupData.
	var gd_script = load("res://addons/siemens_plugin/plc/var_groups/GroupData.cs")
	if not gd_script:
		push_error("PlcSensorBridge: Could not load GroupData.cs")
		return

	var gd_node := Node.new()
	gd_node.name = "SensorBridgeGroup"
	gd_node.set_script(gd_script)
	plc_node.add_child(gd_node)
	_group_data = gd_node


func _find_sensors(node: Node, out: Array[Node]) -> void:
	if node is ColorSensor or node is DiffuseSensor or node is LaserSensor:
		out.append(node)
	for child: Node in node.get_children():
		_find_sensors(child, out)


## Allocates the next available byte address for a sensor based on its data
## size, ensuring BOOL sensors pack into individual bits of a byte while
## REAL and DINT sensors are 4-byte aligned.
func _allocate_address(sensor: Node) -> Dictionary:
	# Check for user override first.
	var override: Dictionary = _address_overrides.get(sensor.get_instance_id(), {})
	if override.size() > 0:
		return override

	var addr: Dictionary = {}

	if sensor is DiffuseSensor:
		# BOOL: 1 bit.  Pack into the current byte (bit 0).
		# For simplicity each BOOL gets its own byte-aligned address.
		addr["start_byte"] = _next_byte_address
		addr["bit"] = 0
		# Advance by 1 byte; next multi-byte item will align to 4-byte
		# boundary in its own branch.
		_next_byte_address += 1

	elif sensor is LaserSensor:
		# REAL: 4 bytes, must be 4-byte aligned.
		_next_byte_address = _align(_next_byte_address, 4)
		addr["start_byte"] = _next_byte_address
		addr["bit"] = 0
		_next_byte_address += 4

	elif sensor is ColorSensor:
		# DINT: 4 bytes, must be 4-byte aligned.
		_next_byte_address = _align(_next_byte_address, 4)
		addr["start_byte"] = _next_byte_address
		addr["bit"] = 0
		_next_byte_address += 4

	return addr


## Round `value` up to the next multiple of `alignment`.
static func _align(value: int, alignment: int) -> int:
	var remainder := value % alignment
	if remainder == 0:
		return value
	return value + (alignment - remainder)


func _register_sensor(sensor: Node) -> void:
	if not _group_data or not is_instance_valid(_group_data):
		return

	var item_node: Node = null
	var addr: Dictionary = _allocate_address(sensor)

	if sensor is DiffuseSensor:
		# DiffuseSensor output is a BOOL.
		var script = load("res://addons/siemens_plugin/plc/var_items/BoolItem.cs")
		if not script:
			return
		item_node = Node.new()
		item_node.set_script(script)
		item_node.name = "Sensor_%s" % sensor.name
		# Write sensor output → PLC (WriteToPlc = 1).
		item_node.set("Mode", 1)
		item_node.set("DataType", 131)  # Memory
		item_node.set("StartByteAdr", addr.get("start_byte", 0))
		item_node.set("BitAdr", addr.get("bit", 0))
		item_node.set("Count", 1)
		item_node.set("VisualComponent", sensor)
		item_node.set("VisualProperty", "output")

	elif sensor is LaserSensor:
		# LaserSensor distance is a REAL (float32).
		var script = load("res://addons/siemens_plugin/plc/var_items/RealItem.cs")
		if not script:
			return
		item_node = Node.new()
		item_node.set_script(script)
		item_node.name = "Sensor_%s" % sensor.name
		item_node.set("Mode", 1)  # WriteToPlc
		item_node.set("DataType", 131)  # Memory
		item_node.set("StartByteAdr", addr.get("start_byte", 4))
		item_node.set("BitAdr", 0)
		item_node.set("Count", 1)
		item_node.set("VisualComponent", sensor)
		item_node.set("VisualProperty", "distance")

	elif sensor is ColorSensor:
		# ColorSensor color_value is a DINT (int32).
		var script = load("res://addons/siemens_plugin/plc/var_items/DIntItem.cs")
		if not script:
			return
		item_node = Node.new()
		item_node.set_script(script)
		item_node.name = "Sensor_%s" % sensor.name
		item_node.set("Mode", 1)  # WriteToPlc
		item_node.set("DataType", 131)  # Memory
		item_node.set("StartByteAdr", addr.get("start_byte", 8))
		item_node.set("BitAdr", 0)
		item_node.set("Count", 1)
		item_node.set("VisualComponent", sensor)
		item_node.set("VisualProperty", "color_value")

	if item_node:
		_group_data.add_child(item_node)
		_registered_sensors.append(sensor)


func _unregister_sensor(sensor: Node3D) -> void:
	if not _group_data or not is_instance_valid(_group_data):
		return
	var target_name := "Sensor_%s" % sensor.name
	for child: Node in _group_data.get_children():
		if child.name == target_name:
			child.queue_free()
			break
	_registered_sensors.erase(sensor)


func _on_connection_changed(connected: bool) -> void:
	if connected:
		# Re-scan when connection comes up.
		register_sensors()
	else:
		unregister_all()
