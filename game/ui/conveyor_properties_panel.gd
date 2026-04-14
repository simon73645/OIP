extends PanelContainer
## Right-side panel for editing Belt Conveyor properties (speed and direction).
##
## Supports [BeltConveyor] and [CurvedBeltConveyor] nodes.  Shows a speed
## spin-box (m/s) and a forward/reverse toggle.

var _target: Node = null

var _title: Label
var _speed_spin: SpinBox
var _direction_button: CheckButton


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

	# Direction.
	var dir_lbl := Label.new()
	dir_lbl.text = "  Laufrichtung"
	vbox.add_child(dir_lbl)

	_direction_button = CheckButton.new()
	_direction_button.text = " Vorwärts"
	_direction_button.toggled.connect(_on_direction_toggled)
	vbox.add_child(_direction_button)


## Bind the panel to a simulation node.  Shows the panel only if the node is
## a belt conveyor type; hides it otherwise.
func bind(node: Node) -> void:
	_target = node
	if _target == null:
		visible = false
		return

	if node is BeltConveyor:
		var conv := node as BeltConveyor
		_speed_spin.set_value_no_signal(absf(conv.speed))
		_direction_button.set_pressed_no_signal(not conv.reverse_belt)
		_direction_button.text = " Vorwärts" if not conv.reverse_belt else " Rückwärts"
		_title.text = "  Belt Conveyor"
		visible = true
	elif node is CurvedBeltConveyor:
		var conv := node as CurvedBeltConveyor
		_speed_spin.set_value_no_signal(absf(conv.speed))
		_direction_button.set_pressed_no_signal(not conv.reverse_belt)
		_direction_button.text = " Vorwärts" if not conv.reverse_belt else " Rückwärts"
		_title.text = "  Curved Belt Conveyor"
		visible = true
	else:
		visible = false


func unbind() -> void:
	_target = null
	visible = false


# ── Callbacks ────────────────────────────────────────────────────────────────

func _on_speed_changed(value: float) -> void:
	if _target is BeltConveyor:
		(_target as BeltConveyor).speed = value
	elif _target is CurvedBeltConveyor:
		(_target as CurvedBeltConveyor).speed = value


func _on_direction_toggled(button_pressed: bool) -> void:
	# button_pressed == true  → forward (not reversed)
	var reversed := not button_pressed
	_direction_button.text = " Vorwärts" if not reversed else " Rückwärts"

	if _target is BeltConveyor:
		(_target as BeltConveyor).reverse_belt = reversed
	elif _target is CurvedBeltConveyor:
		(_target as CurvedBeltConveyor).reverse_belt = reversed
