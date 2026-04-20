extends PanelContainer
## Right-side panel for editing Belt Conveyor and Chain Transfer properties.
##
## Supports [BeltConveyor], [CurvedBeltConveyor] and [ChainTransfer] nodes.
## Shows a speed spin-box (m/s) and a forward/reverse toggle for belt conveyors,
## or a speed spin-box and popup toggle for chain transfers.

var _target: Node = null

var _title: Label
var _speed_spin: SpinBox
var _direction_button: CheckButton
var _dir_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Styling.
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
	offset_left = -280

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Title.
	_title = Label.new()
	_title.text = "  Belt Conveyor"
	_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_title)

	vbox.add_child(HSeparator.new())

	# Speed.
	var speed_lbl := Label.new()
	speed_lbl.text = "  Geschwindigkeit (m/s)"
	vbox.add_child(speed_lbl)

	_speed_spin = SpinBox.new()
	_speed_spin.min_value = 0.0
	_speed_spin.max_value = 20.0
	_speed_spin.step = 0.1
	_speed_spin.value = 2.0
	_speed_spin.suffix = " m/s"
	_speed_spin.custom_minimum_size.x = 200
	_speed_spin.value_changed.connect(_on_speed_changed)
	vbox.add_child(_speed_spin)

	# Direction / Popup toggle.
	_dir_label = Label.new()
	_dir_label.text = "  Laufrichtung"
	vbox.add_child(_dir_label)

	_direction_button = CheckButton.new()
	_direction_button.text = " Vorwärts"
	_direction_button.toggled.connect(_on_direction_toggled)
	vbox.add_child(_direction_button)


## Bind the panel to a simulation node.  Shows the panel only if the node is
## a belt conveyor type, chain transfer, or an assembly containing one; hides it otherwise.
func bind(node: Node) -> void:
	# Resolve the actual conveyor node — it might be the node itself or a
	# child of an assembly.
	var conveyor := _find_supported_node(node)
	_target = conveyor
	if _target == null:
		visible = false
		return

	if conveyor is BeltConveyor:
		var conv := conveyor as BeltConveyor
		_speed_spin.set_value_no_signal(absf(conv.speed))
		_direction_button.set_pressed_no_signal(not conv.reverse_belt)
		_direction_button.text = " Vorwärts" if not conv.reverse_belt else " Rückwärts"
		_dir_label.text = "  Laufrichtung"
		_title.text = "  Belt Conveyor"
		visible = true
	elif conveyor is CurvedBeltConveyor:
		var conv := conveyor as CurvedBeltConveyor
		_speed_spin.set_value_no_signal(absf(conv.speed))
		_direction_button.set_pressed_no_signal(not conv.reverse_belt)
		_direction_button.text = " Vorwärts" if not conv.reverse_belt else " Rückwärts"
		_dir_label.text = "  Laufrichtung"
		_title.text = "  Curved Belt Conveyor"
		visible = true
	elif conveyor is ChainTransfer:
		var ct := conveyor as ChainTransfer
		_speed_spin.set_value_no_signal(absf(ct.speed))
		_direction_button.set_pressed_no_signal(ct.popup_chains)
		_direction_button.text = " Aktiv" if ct.popup_chains else " Inaktiv"
		_dir_label.text = "  Popup Ketten"
		_title.text = "  Chain Transfer"
		visible = true
	else:
		visible = false


func unbind() -> void:
	_target = null
	visible = false


## Locate the inner belt conveyor or chain transfer node. Assemblies store the
## conveyor as a child named "Conveyor" or "ConveyorCorner".
static func _find_supported_node(node: Node3D) -> Node:
	if node is BeltConveyor or node is CurvedBeltConveyor or node is ChainTransfer:
		return node
	# Check assembly children.
	var child := node.get_node_or_null("Conveyor")
	if child and (child is BeltConveyor or child is CurvedBeltConveyor):
		return child
	child = node.get_node_or_null("ConveyorCorner")
	if child and (child is BeltConveyor or child is CurvedBeltConveyor):
		return child
	return null


# ── Callbacks ────────────────────────────────────────────────────────────────

func _on_speed_changed(value: float) -> void:
	if _target is BeltConveyor:
		(_target as BeltConveyor).speed = value
	elif _target is CurvedBeltConveyor:
		(_target as CurvedBeltConveyor).speed = value
	elif _target is ChainTransfer:
		(_target as ChainTransfer).speed = value


func _on_direction_toggled(button_pressed: bool) -> void:
	if _target is ChainTransfer:
		# button_pressed == true → popup active
		(_target as ChainTransfer).popup_chains = button_pressed
		_direction_button.text = " Aktiv" if button_pressed else " Inaktiv"
	else:
		# button_pressed == true  → forward (not reversed)
		var reversed := not button_pressed
		_direction_button.text = " Vorwärts" if not reversed else " Rückwärts"

		if _target is BeltConveyor:
			(_target as BeltConveyor).reverse_belt = reversed
		elif _target is CurvedBeltConveyor:
			(_target as CurvedBeltConveyor).reverse_belt = reversed
