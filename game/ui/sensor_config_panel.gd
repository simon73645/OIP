extends PanelContainer
## Panel that displays sensor configuration details (name, type, PLC address).
##
## Shows when a sensor is selected and allows viewing (and future editing) of
## sensor properties like PLC address assignment, tag names, etc.

var _sensor: Node3D = null
var _content: VBoxContainer
var _sensor_name_label: Label
var _sensor_type_label: Label
var _address_label: Label
var _enable_comms_checkbox: CheckBox
var _tag_group_line_edit: LineEdit
var _tag_name_line_edit: LineEdit


func _ready() -> void:
	_build_ui()
	hide()


func _build_ui() -> void:
	# Panel styling
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.6, 0.8, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)

	# Content container
	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(280, 0)
	add_child(_content)

	# Margin container for padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_content.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Sensor Configuration"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	vbox.add_child(title)

	# Separator
	var separator1 := HSeparator.new()
	vbox.add_child(separator1)

	# Sensor name
	_sensor_name_label = Label.new()
	_sensor_name_label.text = "Name: -"
	_sensor_name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_sensor_name_label)

	# Sensor type
	_sensor_type_label = Label.new()
	_sensor_type_label.text = "Type: -"
	_sensor_type_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_sensor_type_label)

	# PLC address
	_address_label = Label.new()
	_address_label.text = "PLC Address: -"
	_address_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	vbox.add_child(_address_label)

	# Separator
	var separator2 := HSeparator.new()
	vbox.add_child(separator2)

	# OIP Comms section
	var comms_title := Label.new()
	comms_title.text = "OIP Communications"
	comms_title.add_theme_font_size_override("font_size", 14)
	comms_title.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	vbox.add_child(comms_title)

	# Enable comms checkbox
	_enable_comms_checkbox = CheckBox.new()
	_enable_comms_checkbox.text = "Enable Communications"
	_enable_comms_checkbox.toggled.connect(_on_enable_comms_toggled)
	vbox.add_child(_enable_comms_checkbox)

	# Tag group
	var tag_group_label := Label.new()
	tag_group_label.text = "Tag Group:"
	tag_group_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(tag_group_label)

	_tag_group_line_edit = LineEdit.new()
	_tag_group_line_edit.placeholder_text = "Enter tag group name..."
	_tag_group_line_edit.text_changed.connect(_on_tag_group_changed)
	vbox.add_child(_tag_group_line_edit)

	# Tag name
	var tag_name_label := Label.new()
	tag_name_label.text = "Tag Name:"
	tag_name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(tag_name_label)

	_tag_name_line_edit = LineEdit.new()
	_tag_name_line_edit.placeholder_text = "Enter tag name..."
	_tag_name_line_edit.text_changed.connect(_on_tag_name_changed)
	vbox.add_child(_tag_name_line_edit)

	# Info label
	var info := Label.new()
	info.text = "Note: PLC bridge addresses are\nautomatically assigned on connect."
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(hide_panel)
	vbox.add_child(close_btn)


func show_for(sensor: Node3D) -> void:
	_sensor = sensor
	_update_display()
	show()


func hide_panel() -> void:
	_sensor = null
	hide()


func _update_display() -> void:
	if not _sensor:
		return

	# Update labels
	_sensor_name_label.text = "Name: %s" % _sensor.name

	var sensor_type := "Unknown"
	var address := "Not registered"

	if _sensor is DiffuseSensor:
		sensor_type = "Diffuse Sensor (BOOL)"
		# Try to determine address from PlcSensorBridge (if already registered)
		address = _get_sensor_address(_sensor)
	elif _sensor is LaserSensor:
		sensor_type = "Laser Sensor (REAL)"
		address = _get_sensor_address(_sensor)
	elif _sensor is ColorSensor:
		sensor_type = "Color Sensor (DINT)"
		address = _get_sensor_address(_sensor)

	_sensor_type_label.text = "Type: %s" % sensor_type
	_address_label.text = "PLC Address: %s" % address

	# Update OIP comms fields
	if _sensor.has("enable_comms"):
		_enable_comms_checkbox.set_pressed_no_signal(_sensor.get("enable_comms"))

	if _sensor.has("tag_group_name"):
		_tag_group_line_edit.text = _sensor.get("tag_group_name")

	if _sensor.has("tag_name"):
		_tag_name_line_edit.text = _sensor.get("tag_name")


func _get_sensor_address(sensor: Node) -> String:
	# Try to find the DataItem for this sensor in the PLC bridge
	if not PlcConnectionManager.plc_node:
		return "PLC not connected"

	var plc_node := PlcConnectionManager.plc_node
	var bridge_group: Node = null

	# Find SensorBridgeGroup
	for child in plc_node.get_children():
		if child.name == "SensorBridgeGroup":
			bridge_group = child
			break

	if not bridge_group:
		return "Bridge not initialized"

	# Find matching sensor item
	var sensor_item_name := "Sensor_%s" % sensor.name
	for item in bridge_group.get_children():
		if item.name == sensor_item_name:
			var data_type: int = item.get("DataType")
			var start_byte: int = item.get("StartByteAdr")
			var bit_addr: int = item.get("BitAdr")

			# Format address based on type
			if sensor is DiffuseSensor:
				return "M%d.%d" % [start_byte, bit_addr]
			elif sensor is LaserSensor:
				return "MD%d" % start_byte
			elif sensor is ColorSensor:
				return "MD%d" % start_byte

	return "Not yet registered"


func _on_enable_comms_toggled(enabled: bool) -> void:
	if _sensor and _sensor.has("enable_comms"):
		_sensor.set("enable_comms", enabled)


func _on_tag_group_changed(new_text: String) -> void:
	if _sensor and _sensor.has("tag_group_name"):
		_sensor.set("tag_group_name", new_text)


func _on_tag_name_changed(new_text: String) -> void:
	if _sensor and _sensor.has("tag_name"):
		_sensor.set("tag_name", new_text)
