extends PanelContainer
## Right-side panel for viewing and configuring Diverter PLC settings.
##
## When a Diverter is selected in the simulation, this panel shows:
##   - Diverter name
##   - PLC connection status
##   - Assigned PLC memory address (auto-assigned or user-configured)
##   - Data type information (BOOL)
##   - Option to override the PLC address manually
##   - Manual Divert trigger button (for testing without PLC)

var _target: Node3D = null
var _plc_bridge: Node = null  # PlcSensorBridge reference

var _title: Label
var _type_label: Label
var _status_label: Label
var _address_label: Label
var _datatype_label: Label
var _start_byte_spin: SpinBox
var _bit_spin: SpinBox
var _apply_btn: Button
var _divert_btn: Button
var _info_label: RichTextLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Styling – matches the sensor properties panel.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.94)
	style.corner_radius_top_left = 6
	style.corner_radius_bottom_left = 6
	add_theme_stylebox_override("panel", style)

	# Anchored to the right edge.
	anchor_top = 0.0
	anchor_bottom = 1.0
	anchor_left = 1.0
	anchor_right = 1.0
	offset_top = 50
	offset_bottom = -40
	offset_left = -300

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Title.
	_title = Label.new()
	_title.text = "  Diverter Settings"
	_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_title)

	vbox.add_child(HSeparator.new())

	# ── Info section ─────────────────────────────────────────────────────
	var info_grid := GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 10)
	info_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(info_grid)

	info_grid.add_child(_make_label("  Typ:"))
	_type_label = _make_value_label("Diverter")
	info_grid.add_child(_type_label)

	info_grid.add_child(_make_label("  Datentyp:"))
	_datatype_label = _make_value_label("BOOL")
	info_grid.add_child(_datatype_label)

	info_grid.add_child(_make_label("  SPS-Adresse:"))
	_address_label = _make_value_label("—")
	info_grid.add_child(_address_label)

	info_grid.add_child(_make_label("  PLC-Status:"))
	_status_label = _make_value_label("Nicht verbunden")
	info_grid.add_child(_status_label)

	vbox.add_child(HSeparator.new())

	# ── Address configuration section ────────────────────────────────────
	var addr_title := Label.new()
	addr_title.text = "  Adresse konfigurieren"
	addr_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(addr_title)

	var addr_grid := GridContainer.new()
	addr_grid.columns = 2
	addr_grid.add_theme_constant_override("h_separation", 10)
	addr_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(addr_grid)

	addr_grid.add_child(_make_label("  Start-Byte:"))
	_start_byte_spin = SpinBox.new()
	_start_byte_spin.min_value = 0
	_start_byte_spin.max_value = 65535
	_start_byte_spin.step = 1
	_start_byte_spin.value = 0
	_start_byte_spin.custom_minimum_size.x = 120
	addr_grid.add_child(_start_byte_spin)

	addr_grid.add_child(_make_label("  Bit (0-7):"))
	_bit_spin = SpinBox.new()
	_bit_spin.min_value = 0
	_bit_spin.max_value = 7
	_bit_spin.step = 1
	_bit_spin.value = 0
	_bit_spin.custom_minimum_size.x = 120
	addr_grid.add_child(_bit_spin)

	_apply_btn = Button.new()
	_apply_btn.text = "Adresse übernehmen"
	_apply_btn.custom_minimum_size = Vector2(180, 32)
	_apply_btn.pressed.connect(_on_apply_pressed)
	vbox.add_child(_apply_btn)

	vbox.add_child(HSeparator.new())

	# ── Manual divert trigger ────────────────────────────────────────────
	var test_title := Label.new()
	test_title.text = "  Manueller Test"
	test_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(test_title)

	_divert_btn = Button.new()
	_divert_btn.text = "Divert auslösen"
	_divert_btn.custom_minimum_size = Vector2(180, 36)
	_divert_btn.pressed.connect(_on_divert_pressed)
	vbox.add_child(_divert_btn)

	vbox.add_child(HSeparator.new())

	# ── Info / hint area ─────────────────────────────────────────────────
	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.custom_minimum_size = Vector2(0, 48)
	_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_label.text = ""
	vbox.add_child(_info_label)

	# Listen for connection changes to update status.
	PlcConnectionManager.connection_state_changed.connect(_on_connection_changed)


## Bind the panel to a selected node.  Shows only if the node is a Diverter.
func bind(node: Node3D, plc_bridge: Node = null) -> void:
	_plc_bridge = plc_bridge
	if node is Diverter:
		_target = node
		_refresh()
		visible = true
	else:
		_target = null
		visible = false


func unbind() -> void:
	_target = null
	visible = false


func hide_panel() -> void:
	_target = null
	visible = false


# ── Refresh display ──────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _target:
		return

	_title.text = "  %s" % _target.name

	var connected := PlcConnectionManager.is_connected

	_type_label.text = "Diverter"
	_datatype_label.text = "BOOL"

	# PLC status.
	if connected:
		_status_label.text = "Verbunden"
		_status_label.add_theme_color_override("font_color", Color("#8eef97"))
	else:
		_status_label.text = "Nicht verbunden"
		_status_label.add_theme_color_override("font_color", Color("#ff786b"))

	# Current address.
	if _plc_bridge and connected:
		var info: Dictionary = _plc_bridge.get_diverter_address(_target)
		if info.size() > 0:
			_address_label.text = info.get("address", "—")
			_start_byte_spin.value = info.get("start_byte", 0)
			_bit_spin.value = info.get("bit", 0)
			_info_label.text = "[color=#8eef97]Diverter ist beim PLC registriert.[/color]\n[color=#aaaaaa]Adresse: %s | Modus: Lesen von SPS (ReadFromPlc)[/color]\n\n[color=#aaaaaa]Wenn das Bit auf TRUE gesetzt wird,\nlöst der Diverter aus.[/color]" % info.get("address", "?")
		else:
			_address_label.text = "(nicht registriert)"
			_info_label.text = "[color=#ffde66]Diverter ist noch nicht beim PLC registriert.\nDie Registrierung erfolgt automatisch bei aktiver Verbindung.[/color]"
	elif not connected:
		_address_label.text = "(offline)"
		_info_label.text = "[color=#aaaaaa]Verbinden Sie sich mit der SPS, um die\nDiverter-Adresse zu sehen und zu konfigurieren.\n\nDer Diverter liest einen BOOL-Wert von der SPS.\nBei TRUE wird der Diverter ausgelöst.[/color]"
	else:
		_address_label.text = "—"
		_info_label.text = ""


# ── Helpers ──────────────────────────────────────────────────────────────────

func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	return lbl


func _make_value_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color("#c0c0c0"))
	return lbl


# ── Callbacks ────────────────────────────────────────────────────────────────

func _on_apply_pressed() -> void:
	if not _target or not _plc_bridge:
		_info_label.text = "[color=#ff786b]Kein Diverter ausgewählt oder Bridge nicht verfügbar.[/color]"
		return

	if not PlcConnectionManager.is_connected:
		_info_label.text = "[color=#ff786b]Nicht mit SPS verbunden. Bitte zuerst verbinden.[/color]"
		return

	var start_byte := int(_start_byte_spin.value)
	var bit := int(_bit_spin.value)
	_plc_bridge.set_diverter_address(_target, start_byte, bit)
	_refresh()
	_info_label.text = "[color=#8eef97]Adresse erfolgreich aktualisiert.[/color]"


func _on_divert_pressed() -> void:
	if _target and _target is Diverter:
		(_target as Diverter).divert()


func _on_connection_changed(_connected: bool) -> void:
	if _target:
		_refresh()
