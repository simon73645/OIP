extends Window
## Modal dialog for configuring and managing the SPS/PLC connection.
##
## Provides input fields for IP, CPU type, Rack, Slot and buttons
## for Connect, Disconnect, Ping, and toggling Online mode.

# ── UI nodes ─────────────────────────────────────────────────────────────────

var _ip_edit: LineEdit
var _cpu_option: OptionButton
var _rack_spin: SpinBox
var _slot_spin: SpinBox
var _connect_btn: Button
var _disconnect_btn: Button
var _ping_btn: Button
var _online_btn: Button
var _status_color: ColorRect
var _status_label: Label
var _info_label: RichTextLabel


func _ready() -> void:
	title = "SPS Connection"
	size = Vector2i(420, 480)
	exclusive = true
	transient = true
	unresizable = false
	close_requested.connect(hide)

	_build_ui()
	_sync_from_manager()
	_connect_event_bus()


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# ── Status bar ──────────────────────────────────────────────────────
	_status_color = ColorRect.new()
	_status_color.custom_minimum_size = Vector2(0, 32)
	_status_color.color = Color("#ffde66")  # Unknown
	vbox.add_child(_status_color)

	_status_label = Label.new()
	_status_label.text = "Unknown"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status_color.add_child(_status_label)

	# ── Connection parameters ───────────────────────────────────────────
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	# IP
	grid.add_child(_label("IP Address:"))
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.0.1"
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_ip_edit)

	# CPU Type
	grid.add_child(_label("CPU Type:"))
	_cpu_option = OptionButton.new()
	for cpu_name: String in PlcConnectionManager.get_cpu_type_names():
		_cpu_option.add_item(cpu_name)
	_cpu_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_cpu_option)

	# Rack
	grid.add_child(_label("Rack:"))
	_rack_spin = SpinBox.new()
	_rack_spin.min_value = 0
	_rack_spin.max_value = 15
	_rack_spin.value = 0
	_rack_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_rack_spin)

	# Slot
	grid.add_child(_label("Slot:"))
	_slot_spin = SpinBox.new()
	_slot_spin.min_value = 0
	_slot_spin.max_value = 31
	_slot_spin.value = 1
	_slot_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_slot_spin)

	# ── Action buttons ──────────────────────────────────────────────────
	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 8)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_box)

	_connect_btn = Button.new()
	_connect_btn.text = "Connect"
	_connect_btn.custom_minimum_size = Vector2(90, 36)
	_connect_btn.pressed.connect(_on_connect_pressed)
	btn_box.add_child(_connect_btn)

	_disconnect_btn = Button.new()
	_disconnect_btn.text = "Disconnect"
	_disconnect_btn.custom_minimum_size = Vector2(90, 36)
	_disconnect_btn.disabled = true
	_disconnect_btn.pressed.connect(_on_disconnect_pressed)
	btn_box.add_child(_disconnect_btn)

	_ping_btn = Button.new()
	_ping_btn.text = "Ping"
	_ping_btn.custom_minimum_size = Vector2(70, 36)
	_ping_btn.pressed.connect(_on_ping_pressed)
	btn_box.add_child(_ping_btn)

	_online_btn = Button.new()
	_online_btn.text = "Online"
	_online_btn.toggle_mode = true
	_online_btn.custom_minimum_size = Vector2(70, 36)
	_online_btn.disabled = true
	_online_btn.toggled.connect(_on_online_toggled)
	btn_box.add_child(_online_btn)

	# ── Info area ───────────────────────────────────────────────────────
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.custom_minimum_size = Vector2(0, 60)
	_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_label.text = ""
	vbox.add_child(_info_label)


func _label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	return lbl


# ── Sync state from PlcConnectionManager ─────────────────────────────────────

func _sync_from_manager() -> void:
	_ip_edit.text = PlcConnectionManager.plc_ip

	# Select the right CPU type.
	var cpu_name := PlcConnectionManager.cpu_type_to_name(PlcConnectionManager.plc_cpu_type)
	for i: int in range(_cpu_option.item_count):
		if _cpu_option.get_item_text(i) == cpu_name:
			_cpu_option.select(i)
			break

	_rack_spin.value = PlcConnectionManager.plc_rack
	_slot_spin.value = PlcConnectionManager.plc_slot
	_update_status_display(PlcConnectionManager.is_connected)


func _push_to_manager() -> void:
	PlcConnectionManager.plc_ip = _ip_edit.text.strip_edges()
	PlcConnectionManager.plc_cpu_type = PlcConnectionManager.cpu_type_from_name(
		_cpu_option.get_item_text(_cpu_option.selected)
	)
	PlcConnectionManager.plc_rack = int(_rack_spin.value)
	PlcConnectionManager.plc_slot = int(_slot_spin.value)


# ── Button handlers ──────────────────────────────────────────────────────────

func _on_connect_pressed() -> void:
	_push_to_manager()
	_info_label.text = "[color=#aaaaaa]Connecting to %s …[/color]" % _ip_edit.text.strip_edges()
	PlcConnectionManager.connect_plc()


func _on_disconnect_pressed() -> void:
	_info_label.text = "[color=#aaaaaa]Disconnecting…[/color]"
	PlcConnectionManager.disconnect_plc()


func _on_ping_pressed() -> void:
	_push_to_manager()
	PlcConnectionManager.ensure_plc_node()
	_info_label.text = "[color=#aaaaaa]Pinging %s …[/color]" % _ip_edit.text.strip_edges()
	PlcConnectionManager.ping_plc()


func _on_online_toggled(pressed: bool) -> void:
	PlcConnectionManager.set_online(pressed)
	if pressed:
		_info_label.text = "[color=#8eef97]Online mode enabled.[/color]"
	else:
		_info_label.text = "[color=#ffde66]Online mode disabled.[/color]"


# ── EventBus wiring ─────────────────────────────────────────────────────────

func _connect_event_bus() -> void:
	PlcConnectionManager.connection_state_changed.connect(_update_status_display)

	if EventBus:
		EventBus.ping_completed.connect(_on_ping_completed)
		EventBus.plc_connection_attempt.connect(_on_connection_attempt)
		EventBus.plc_connection_failed.connect(_on_connection_failed)


func _update_status_display(connected: bool) -> void:
	if connected:
		_status_color.color = Color("#8eef97")
		_status_label.text = "Connected"
		_status_label.add_theme_color_override("font_color", Color("#5c9a62"))
		_connect_btn.disabled = true
		_disconnect_btn.disabled = false
		_ping_btn.disabled = true
		_online_btn.disabled = false
		_ip_edit.editable = false
		_info_label.text = "[color=#8eef97]Successfully connected to PLC.[/color]"
	else:
		_status_color.color = Color("#ff786b")
		_status_label.text = "Disconnected"
		_status_label.add_theme_color_override("font_color", Color("#95463f"))
		_connect_btn.disabled = false
		_disconnect_btn.disabled = true
		_ping_btn.disabled = false
		_online_btn.disabled = true
		_online_btn.set_pressed_no_signal(false)
		_ip_edit.editable = true


func _on_ping_completed(ip: String, success: bool) -> void:
	if success:
		_info_label.text = "[color=#8eef97]Ping to %s successful.[/color]" % ip
	else:
		_info_label.text = "[color=#ff786b]Ping to %s failed.[/color]" % ip


func _on_connection_attempt(attempt: int, max_attempts: int) -> void:
	_info_label.text = "[color=#aaaaaa]Connection attempt %d/%d …[/color]" % [attempt, max_attempts]


func _on_connection_failed(_plc: Node, error: String) -> void:
	_info_label.text = "[color=#ff786b]Connection failed: %s[/color]" % error
