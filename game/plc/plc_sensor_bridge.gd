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

var _simulation_root: Node3D = null
var _group_data: Node = null  # GroupData C# node
var _registered_sensors: Array[Node3D] = []


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


## Removes all registered items (e.g. on disconnect).
func unregister_all() -> void:
	if _group_data and is_instance_valid(_group_data):
		for child: Node in _group_data.get_children():
			child.queue_free()
	_registered_sensors.clear()


# ── Internal helpers ─────────────────────────────────────────────────────────

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


func _register_sensor(sensor: Node) -> void:
	if not _group_data or not is_instance_valid(_group_data):
		return

	var item_node: Node = null

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
		item_node.set("Count", 1)
		item_node.set("VisualComponent", sensor)
		item_node.set("VisualProperty", "color_value")

	if item_node:
		_group_data.add_child(item_node)
		_registered_sensors.append(sensor)


func _on_connection_changed(connected: bool) -> void:
	if connected:
		# Re-scan when connection comes up.
		register_sensors()
	else:
		unregister_all()
